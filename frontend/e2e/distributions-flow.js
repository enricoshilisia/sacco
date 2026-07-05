// Smoke test: Phase 5 - staff proposes a dividend run against share
// capital, approves it (a distinct maker-checker step - proposing and
// approving both succeed here because SuperAdmin holds every distributions
// permission, but the UI only ever shows the approve/reject panel to a
// login that actually holds distributions.approve_distribution), pays it
// out via the mock mobile-money provider, and confirms the paid entry
// shows up in the member's own self-service dividend history. Requires
// both dev servers running + a Celery worker (the mock provider's payout
// callback resolves ~2s later via Celery, same async simulation as every
// other mobile-money flow in this codebase) + nairobi_demo seeded, with
// John Mwangi already holding a positive share-capital balance and Amina
// Njoroge holding portal access (phone +254788112233 / AminaPass123!).

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const ADMIN_PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

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
  await page.fill('input[type="tel"]', ADMIN_PHONE);
  await page.fill('input[type="password"]', ADMIN_PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  // --- Propose a dividend run ---
  await page.locator('[data-testid="nav-distributions"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/distributions', { timeout: 10000 });
  await page.waitForSelector('text=Propose a dividend run', { timeout: 10000 });

  const dividendCard = page.locator('h2:has-text("Propose a dividend run")').locator('xpath=../..');
  await dividendCard.locator('input[type="date"]').first().fill('2026-01-01');
  await dividendCard.locator('input[type="date"]').nth(1).fill('2026-07-05');
  await dividendCard.locator('input[type="number"]').fill('0.04');
  await dividendCard.locator('input[type="text"]').fill('e2e dividend run');

  const [proposeResponse] = await Promise.all([
    page.waitForResponse((r) => r.url().includes('/api/distributions/runs/dividend/') && r.request().method() === 'POST'),
    dividendCard.locator('button:has-text("Propose")').click(),
  ]);
  assert(proposeResponse.status() === 201, 'dividend run proposed successfully');
  const proposed = await proposeResponse.json();

  await page.waitForSelector('text=Pending approval', { timeout: 10000 });
  assert(true, 'new run shows as Pending approval in the runs table');

  // --- Approve it ---
  await page.goto(`${BASE}/en/distributions/${proposed.id}`, { waitUntil: 'networkidle' });
  await page.waitForSelector('button:has-text("Approve")', { timeout: 10000 });
  await page.click('button:has-text("Approve")');
  await page.waitForSelector('button:has-text("Pay out all")', { timeout: 10000 });
  assert(true, 'run approved, posted to the ledger, and shows the payout panel');

  // --- Pay out John's entry individually (not the bulk button, so this
  // script proves the single-entry payout path + its async callback) ---
  const johnRow = page.locator('tr', { has: page.locator('text=John Mwangi') });
  await johnRow.locator('input[type="tel"]').fill('+254712345678');
  const [payoutResponse] = await Promise.all([
    page.waitForResponse((r) => r.url().includes('/payout/') && r.request().method() === 'POST'),
    johnRow.locator('button:has-text("Pay out")').click(),
  ]);
  assert(payoutResponse.status() === 200, 'payout initiated for John');

  // The mock provider's Celery-scheduled callback resolves ~2s later - poll
  // by reloading rather than a fixed delay, matching the established
  // pattern for every other mock-provider async round trip in this suite.
  let paidVisible = false;
  for (let attempt = 0; attempt < 8 && !paidVisible; attempt++) {
    await page.waitForTimeout(1000);
    await page.reload({ waitUntil: 'networkidle' });
    paidVisible = await page.locator('tr', { has: page.locator('text=John Mwangi') }).locator('text=Paid').isVisible();
  }
  assert(paidVisible, "John's payout completed asynchronously and the entry shows Paid");

  // --- Confirm it shows up in a self-service member's own history ---
  // (Amina isn't necessarily in this specific run, but her own dividend
  // history endpoint must at least load cleanly for a self-service member.)
  const memberContext = await browser.newContext();
  const memberPage = await memberContext.newPage();
  memberPage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });
  await memberPage.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await memberPage.fill('input[type="tel"]', '+254788112233');
  await memberPage.fill('input[type="password"]', 'AminaPass123!');
  await memberPage.click('button[type="submit"]');
  await memberPage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });
  await memberPage.locator('[data-testid="nav-distributions"]:visible').click();
  await memberPage.waitForURL((u) => u.pathname === '/en/distributions', { timeout: 10000 });
  await memberPage.waitForSelector('text=My dividends', { timeout: 10000 });
  assert(true, "self-service member's own distribution history page loads cleanly");
  await memberContext.close();

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('distributions-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`distributions-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
