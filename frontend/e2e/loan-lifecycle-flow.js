// Smoke test: Phase 4 slice 2 - an approved loan can actually be
// disbursed, repaid, and closed from the UI, not just sit at APPROVED
// forever. Applies for a no-guarantor Emergency Loan, which now
// auto-approves immediately under its rules_engine eligibility policy
// (no manual appraise/decide - see loans-flow.js's header for the same
// change), disburses it straight to the member's own savings account,
// confirms the amortization schedule and savings balance both update,
// records a partial repayment, then pays it off and confirms the loan
// closes. Separately, disburses a second loan via the mock mobile-money
// path, confirms the async initiate -> DISBURSED -> (Celery callback) ->
// ACTIVE round trip completes and renders correctly, then repays and
// closes that one too (so it can't linger as an overdue ACTIVE loan and
// flip future auto-decisions, given this project's e2e scripts don't
// clean up test data between runs). Requires both dev servers running
// (with a Celery worker that's been restarted since this phase's code
// landed - it registers new tasks at startup) + nairobi_demo seeded.

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
  // Emergency Loan has an active eligibility policy (rules_engine) - a
  // clean, KYC-verified, arrears-free member auto-approves immediately.
  await page.waitForSelector('text=Approved', { timeout: 10000 });
  assert(true, 'no-guarantor loan auto-approved immediately under the Emergency Loan eligibility policy');

  await loansCard.locator('a:has-text("Emergency Loan")').first().click();
  await page.waitForURL((u) => /\/en\/loans\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=Disburse', { timeout: 10000 });
  assert(true, 'loan detail page opens straight into the disburse panel (no manual appraisal needed)');

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
  await page.waitForSelector('text=Approved', { timeout: 10000 });
  assert(true, 'no-guarantor loan auto-approved immediately under the Emergency Loan eligibility policy');

  await johnLoansCard.locator('a:has-text("Emergency Loan")').first().click();
  await page.waitForURL((u) => /\/en\/loans\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
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

  // Repay and close this loan too, rather than leaving it permanently
  // ACTIVE - this project's e2e scripts don't clean up test data between
  // runs, and an unpaid loan would eventually fall into arrears, which
  // would flip the Emergency Loan eligibility policy's
  // require_no_active_arrears check and make John's *future* auto-approvals
  // in this exact test start auto-denying instead.
  await page.fill('input[placeholder="Amount"]', '300');
  await page.fill('input[type="date"]', '2026-07-04');
  await page.click('button:has-text("Record repayment")');
  await page.waitForSelector('text=Closed', { timeout: 10000 });
  assert(await page.isVisible('text=Closed on'), "John's mobile-money loan is also repaid and closed, so it can't linger as an overdue ACTIVE loan and poison future auto-decisions across repeated e2e runs");

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
