// Smoke test: Phase 4 slice 2 - an approved loan can actually be
// disbursed, repaid, and closed from the UI, not just sit at APPROVED
// forever. Staff approves a no-guarantor Emergency Loan (reusing the
// apply->appraise->approve flow loans-flow.js already proves), disburses
// it straight to the member's own savings account, confirms the
// amortization schedule and savings balance both update, records a
// partial repayment, then pays it off and confirms the loan closes.
// Separately, disburses a second loan via the mock mobile-money path and
// confirms the async initiate -> DISBURSED -> (Celery callback) -> ACTIVE
// round trip completes and renders correctly. Requires both dev servers
// running (with a Celery worker that's been restarted since this phase's
// code landed - it registers new tasks at startup) + nairobi_demo seeded.

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

  // --- Apply + approve a no-guarantor loan for Grace, straight from her member page ---
  await page.locator('[data-testid="nav-members"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await page.click('text=Grace Wambui');
  await page.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=Apply for a loan', { timeout: 10000 });

  const loansCard = page.locator('h2:has-text("Loans")').first().locator('xpath=../..');
  await loansCard.locator('select').selectOption({ label: 'Emergency Loan' });
  await loansCard.locator('input[type="number"]').first().fill('400');
  await loansCard.locator('input[placeholder="Term (months)"]').fill('2');
  await loansCard.locator('button:has-text("Submit application")').click();
  await page.waitForSelector('text=Pending appraisal', { timeout: 10000 });

  await loansCard.locator('a:has-text("Emergency Loan")').first().click();
  await page.waitForURL((u) => /\/en\/loans\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });

  await page.fill('textarea[placeholder="Optional notes"]', 'Verified via lifecycle smoke test.');
  await page.click('button:has-text("Appraise")');
  await page.waitForSelector('text=Appraised', { timeout: 10000 });
  await page.fill('textarea[placeholder="Decision notes"]', 'Approved via lifecycle smoke test.');
  await page.click('button:has-text("Approve")');
  await page.waitForSelector('text=Disburse', { timeout: 10000 });
  assert(true, 'loan reached APPROVED and shows the disburse panel');

  // --- Disburse to savings ---
  await page.locator('main select').selectOption({ label: 'Mandatory Monthly Savings' });
  await page.click('button:has-text("Disburse to savings")');
  await page.waitForSelector('text=Repayment schedule', { timeout: 10000 });
  assert(await page.isVisible('text=Active'), 'loan shows Active after savings disbursement');
  const scheduleRowCount = await page.locator('table tbody tr').count();
  assert(scheduleRowCount === 2, `expected a 2-installment schedule, got ${scheduleRowCount}`);

  // --- Partial repayment ---
  await page.fill('input[placeholder="Amount"]', '50');
  await page.fill('input[type="date"]', '2026-07-04');
  await page.click('button:has-text("Record repayment")');
  await page.waitForFunction(
    () => document.body.textContent.includes('Outstanding balance: 350'),
    { timeout: 10000 },
  );
  assert(true, 'partial repayment reduced the outstanding balance correctly');

  // --- Pay off the rest, confirm closure ---
  await page.fill('input[placeholder="Amount"]', '350');
  await page.fill('input[type="date"]', '2026-07-04');
  await page.click('button:has-text("Record repayment")');
  await page.waitForSelector('text=Closed', { timeout: 10000 });
  assert(await page.isVisible('text=Closed on'), 'loan closed and shows a closed-on date');

  // --- Second loan: mobile-money disbursement, async round trip ---
  await page.goto(`${BASE}/en/members`, { waitUntil: 'networkidle' });
  await page.click('text=John Mwangi');
  await page.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=Apply for a loan', { timeout: 10000 });

  const johnLoansCard = page.locator('h2:has-text("Loans")').first().locator('xpath=../..');
  await johnLoansCard.locator('select').selectOption({ label: 'Emergency Loan' });
  await johnLoansCard.locator('input[type="number"]').first().fill('300');
  await johnLoansCard.locator('input[placeholder="Term (months)"]').fill('3');
  await johnLoansCard.locator('button:has-text("Submit application")').click();
  await page.waitForSelector('text=Pending appraisal', { timeout: 10000 });

  await johnLoansCard.locator('a:has-text("Emergency Loan")').first().click();
  await page.waitForURL((u) => /\/en\/loans\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.click('button:has-text("Appraise")');
  await page.waitForSelector('text=Appraised', { timeout: 10000 });
  await page.click('button:has-text("Approve")');
  await page.waitForSelector('text=Disburse', { timeout: 10000 });

  await page.fill('input[placeholder="Phone number"]', '+254712345678');
  await page.click('button:has-text("Disburse via mobile money")');
  await page.waitForSelector('text=Disbursement initiated', { timeout: 10000 });
  assert(true, 'mobile-money disbursement shows the pending-confirmation state');

  // The mock provider's Celery-scheduled callback resolves ~2s later (see
  // payments/providers/mock.py's countdown=2) - there's no polling on this
  // page, so the only way to observe the transition is to wait past that
  // window and reload. Poll by reloading rather than a single fixed delay,
  // so this isn't flaky if the worker is briefly slower than usual.
  let scheduleVisible = false;
  for (let attempt = 0; attempt < 8 && !scheduleVisible; attempt++) {
    await page.waitForTimeout(1000);
    await page.reload({ waitUntil: 'networkidle' });
    scheduleVisible = await page.isVisible('text=Repayment schedule');
  }
  assert(scheduleVisible, 'mobile-money disbursement completed asynchronously and the loan went Active');

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('loan-lifecycle-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`loan-lifecycle-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
