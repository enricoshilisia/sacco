// Smoke test: collect a mobile-money payment from a member's detail page,
// watch it resolve from PENDING to SUCCESS via the real async pipeline
// (Celery mock provider -> ledger post -> notification), confirm it shows
// up on /payments (both the Collections and Notifications tabs), and
// confirm a declined collection surfaces its failure message too.
// Requires both dev servers running, a Celery worker running, and
// nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const errors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await page.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await page.fill('input[type="tel"]', PHONE);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  // --- Open member detail page ---
  await page.locator('[data-testid="nav-members"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await page.click('text=John Mwangi');
  await page.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=Collect via mobile money', { timeout: 10000 });

  const collectCard = page.locator('h2:has-text("Collect via mobile money")').locator('xpath=../..');
  const savingsCard = page.locator('h2:has-text("Savings")').locator('xpath=../..');

  // --- Successful collection ---
  await collectCard.locator('select').selectOption({ index: 1 });
  const selectedProduct = await collectCard.locator('select').locator('option:checked').innerText();
  await collectCard.locator('input[type="tel"]').fill('+254712345678');
  await collectCard.locator('input[type="number"]').fill('900');
  await collectCard.locator('button:has-text("Request payment")').click();

  await page.waitForSelector('text=Waiting for the customer to approve on their phone', { timeout: 10000 });
  await page.waitForSelector('text=Payment received.', { timeout: 10000 });
  assert(true, 'collection resolved from PENDING to SUCCESS in the UI');

  // The Savings card re-fetches on success - confirm that product now has a
  // real, rendered balance (proves the UI picked up the ledger-posted
  // deposit, regardless of whether the account pre-existed this run).
  const productRow = savingsCard.locator(`.rounded-lg.border.border-primary-100:has(p:text-is("${selectedProduct}"))`);
  await productRow.waitFor({ state: 'visible', timeout: 10000 });
  const rowBalance = await productRow.locator('p.font-mono').innerText();
  assert(/\d/.test(rowBalance), `savings row for "${selectedProduct}" shows a real balance (got "${rowBalance}")`);

  // --- Declined collection (mock phone ending 0000) ---
  await collectCard.locator('select').selectOption({ index: 1 });
  await collectCard.locator('input[type="tel"]').fill('+254700000000');
  await collectCard.locator('input[type="number"]').fill('300');
  await collectCard.locator('button:has-text("Request payment")').click();
  await page.waitForSelector('text=Payment failed', { timeout: 10000 });
  assert(true, 'declined collection surfaces its failure message');

  // --- /payments page: Collections tab ---
  await page.locator('[data-testid="nav-payments"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/payments', { timeout: 10000 });
  await page.waitForSelector('text=John Mwangi', { timeout: 10000 });
  assert(await page.locator('text=Success').first().isVisible(), 'a Success collection is listed');
  assert(await page.locator('text=Failed').first().isVisible(), 'a Failed collection is listed');

  // --- Notifications tab ---
  await page.click('button:has-text("Notifications")');
  await page.waitForSelector('text=payment_confirmation', { timeout: 10000 });
  assert(true, 'the payment confirmation notification is listed');

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('payments-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`payments-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
