// Smoke test: a self-service member (no staff permissions) sees a Savings
// nav item, lands on a /savings page showing their share capital + savings
// balances, and can fund a share contribution and a savings deposit via the
// mock mobile-money provider (POST /api/payments/me/collect/) - covering the
// "where to add shares" half of the "make the member dashboard have their
// menus" request (the other half, a self-service Loans page, is covered by
// member-self-service-loan-flow.js). Requires both dev servers + the Celery
// worker running (the mock provider's callback is scheduled 2s later via
// Celery, same async simulation as every other mobile-money flow in this
// codebase) + nairobi_demo seeded, with Amina Njoroge already holding portal
// access (phone +254788112233 / AminaPass123!).

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const AMINA_PHONE = '+254788112233';
const AMINA_PASSWORD = 'AminaPass123!';

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
  await page.fill('input[type="tel"]', AMINA_PHONE);
  await page.fill('input[type="password"]', AMINA_PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  // --- Savings nav item is visible and navigates to /savings ---
  // myMemberId resolves asynchronously (a GET to /api/members/me/ fired from
  // TenantProfileContext), so the nav item may not be there on the very
  // first paint - wait for it rather than checking immediately.
  await page.waitForSelector('[data-testid="nav-savings"]:visible', { timeout: 10000 });
  await page.locator('[data-testid="nav-savings"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/savings', { timeout: 10000 });
  await page.waitForSelector('text=Contribute shares', { timeout: 10000 });
  await page.waitForSelector('text=Deposit savings', { timeout: 10000 });

  const sharesCard = page.locator('h2:has-text("Share capital")').locator('xpath=../..');
  const savingsCard = page.locator('h2:has-text("Savings accounts")').locator('xpath=../..');

  const shareBalanceBefore = (await sharesCard.locator('p.text-2xl').innerText()).trim();

  // --- Contribute shares via mock M-Pesa ---
  await sharesCard.locator('input[type="number"]').fill('500');
  await sharesCard.locator('input[type="tel"]').fill('254788112233');
  await Promise.all([
    page.waitForResponse((r) => r.url().includes('/api/payments/me/collect/') && r.request().method() === 'POST'),
    sharesCard.locator('button:has-text("Contribute via M-Pesa")').click(),
  ]);
  await page.waitForSelector('text=Prompt sent', { timeout: 10000 });
  assert(true, 'share contribution collection initiated');

  // Mock provider's callback fires ~2s later via Celery; poll by reloading
  // rather than waitForFunction on body text (that false-positives against
  // the embedded i18n bundle - see loan-lifecycle-flow.js for the same fix).
  let shareBalanceAfter = shareBalanceBefore;
  for (let attempt = 0; attempt < 8 && shareBalanceAfter === shareBalanceBefore; attempt++) {
    await page.waitForTimeout(1000);
    await page.reload({ waitUntil: 'networkidle' });
    shareBalanceAfter = (await page.locator('h2:has-text("Share capital")').locator('xpath=../..').locator('p.text-2xl').innerText()).trim();
  }
  assert(shareBalanceAfter !== shareBalanceBefore, `share balance updated after mock callback (was ${shareBalanceBefore}, still ${shareBalanceAfter})`);

  // --- Deposit into a savings product via mock M-Pesa ---
  const savingsCard2 = page.locator('h2:has-text("Savings accounts")').locator('xpath=../..');
  await savingsCard2.locator('select').selectOption({ label: 'Voluntary Savings' });
  await savingsCard2.locator('input[type="number"]').fill('300');
  await savingsCard2.locator('input[type="tel"]').fill('254788112233');
  await Promise.all([
    page.waitForResponse((r) => r.url().includes('/api/payments/me/collect/') && r.request().method() === 'POST'),
    savingsCard2.locator('button:has-text("Deposit via M-Pesa")').click(),
  ]);
  await page.waitForSelector('text=Prompt sent', { timeout: 10000 });
  assert(true, 'savings deposit collection initiated');

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('member-self-service-savings-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`member-self-service-savings-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
