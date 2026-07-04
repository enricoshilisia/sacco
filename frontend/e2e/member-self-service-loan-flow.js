// Smoke test: a self-service member (no staff permissions) can apply for a
// loan from their own Loans page (nav item -> /loans, self-service view), and
// - for a product requiring guarantors - add a guarantor by member number
// from the loan detail page and submit for appraisal, entirely without the
// `members.view`/`loans.manage_guarantor_pledge` staff permissions. Covers
// the two self-service gaps found while investigating "members i see only
// dashboard menu alone": no apply-for-a-loan UI existed for members, and the
// guarantor/submit UI on the loan detail page was staff-only with no
// borrower-ownership fallback. The apply form used to live inline on the
// Dashboard; it now lives on its own /loans page (see the "professional
// navigation" follow-up that gave members a real Loans/Savings menu instead
// of one crowded Dashboard). Requires both dev servers running + nairobi_demo
// seeded, with Amina Njoroge already holding portal access (phone
// +254788112233 / AminaPass123!).

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

  // --- Navigate to the self-service Loans page via its nav item ---
  await page.locator('[data-testid="nav-loans"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/loans', { timeout: 10000 });
  await page.waitForSelector('text=Apply for a loan', { timeout: 10000 });
  assert((await page.locator('table').count()) === 0, 'self-service member sees no staff loans table');

  const myLoansCard = page.locator('h2:has-text("My loans")').locator('xpath=../..');
  const applyCard = page.locator('h2:has-text("Apply for a loan")').locator('xpath=../..');

  // --- Apply for a no-guarantor loan ---
  await applyCard.locator('select').selectOption({ label: 'Emergency Loan' });
  await applyCard.locator('input[type="number"]').first().fill('150');
  await applyCard.locator('input[type="number"]').nth(1).fill('3');
  await applyCard.locator('input[type="text"]').fill('School fees');
  // Wait for the apply POST to actually resolve (not just for "Pending
  // appraisal" text to appear) - Amina's dashboard can carry loans left
  // over from earlier runs already in that status, which would make a
  // text-based wait resolve immediately without the form having reset yet.
  await Promise.all([
    page.waitForResponse((r) => r.url().includes('/api/loans/me/apply/') && r.request().method() === 'POST'),
    applyCard.locator('button:has-text("Submit application")').click(),
  ]);
  await page.waitForSelector('text=Pending appraisal', { timeout: 10000 });
  assert(true, 'self-service member applied for a no-guarantor loan from the Dashboard');

  // --- Apply for a loan that requires guarantors ---
  await applyCard.locator('select').selectOption({ label: 'Development Loan' });
  await applyCard.locator('input[type="number"]').first().fill('200');
  await applyCard.locator('input[type="number"]').nth(1).fill('6');
  await applyCard.locator('input[type="text"]').fill('Small business');
  await Promise.all([
    page.waitForResponse((r) => r.url().includes('/api/loans/me/apply/') && r.request().method() === 'POST'),
    applyCard.locator('button:has-text("Submit application")').click(),
  ]);
  await page.waitForSelector('text=Awaiting guarantors', { timeout: 10000 });
  assert(true, 'self-service member applied for a loan requiring guarantors');

  await myLoansCard.locator('a:has-text("Development Loan")').first().click();
  await page.waitForURL((u) => /\/en\/loans\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=No guarantors added yet.', { timeout: 10000 });

  // No `members.view`, so this must be the member-number text input, not a dropdown.
  assert((await page.locator('main select').count()) === 0, 'no staff member-picker dropdown shown to a self-service borrower');
  await page.fill('input[placeholder="Guarantor\'s member number"]', 'M-00001');
  await page.fill('input[placeholder="Pledged amount"]', '250');
  await page.click('button:has-text("Add")');
  await page.waitForSelector('text=John Mwangi', { timeout: 10000 });
  assert(true, 'self-service borrower added a guarantor by member number');

  // Development Loan needs 2 CONSENTED guarantors; only 1 was just added and
  // hasn't consented yet, so this proves the borrower can reach and invoke
  // the submit action (the ownership fix), not that it fully succeeds here.
  await page.click('button:has-text("Submit for appraisal")');
  await page.waitForSelector('text=consenting guarantor', { timeout: 10000 });
  assert(true, 'self-service borrower invoked submit-for-appraisal and got the expected not-enough-guarantors error');

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('member-self-service-loan-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`member-self-service-loan-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
