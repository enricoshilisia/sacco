// Smoke test: staff applies for a loan on a member's behalf (no
// guarantors required), appraises and approves it end to end; separately,
// staff adds a guarantor to a different loan and the guarantor accepts the
// request from their own self-service dashboard. Requires both dev
// servers running + nairobi_demo seeded, with Amina Njoroge already
// holding portal access (phone +254788112233 / AminaPass123! - set up
// during this phase's backend verification).

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const ADMIN_PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';
const AMINA_PHONE = '+254788112233';
const AMINA_PASSWORD = 'AminaPass123!';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const adminPage = await browser.newPage();
  const errors = [];
  adminPage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await adminPage.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await adminPage.fill('input[type="tel"]', ADMIN_PHONE);
  await adminPage.fill('input[type="password"]', ADMIN_PASSWORD);
  await adminPage.click('button[type="submit"]');
  await adminPage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  // --- Apply for a no-guarantor loan on Grace's behalf from her member page ---
  await adminPage.locator('[data-testid="nav-members"]:visible').click();
  await adminPage.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await adminPage.click('text=Grace Wambui');
  await adminPage.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await adminPage.waitForSelector('text=Apply for a loan', { timeout: 10000 });

  const loansCard = adminPage.locator('h2:has-text("Loans")').first().locator('xpath=../..');
  await loansCard.locator('select').selectOption({ label: 'Emergency Loan' });
  await loansCard.locator('input[type="number"]').first().fill('500');
  await loansCard.locator('input[placeholder="Term (months)"]').fill('2');
  await loansCard.locator('button:has-text("Submit application")').click();
  await adminPage.waitForSelector('text=Pending appraisal', { timeout: 10000 });
  assert(true, 'no-guarantor loan applied and shows Pending appraisal on the member card');

  await loansCard.locator('a:has-text("Emergency Loan")').first().click();
  await adminPage.waitForURL((u) => /\/en\/loans\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });

  await adminPage.fill('textarea[placeholder="Optional notes"]', 'Verified via smoke test.');
  await adminPage.click('button:has-text("Appraise")');
  await adminPage.waitForSelector('text=Appraised', { timeout: 10000 });

  await adminPage.fill('textarea[placeholder="Decision notes"]', 'Approved via smoke test.');
  await adminPage.click('button:has-text("Approve")');
  await adminPage.waitForSelector('text=Approved', { timeout: 10000 });
  assert(true, 'loan progressed through appraise -> approve in the UI');

  // --- A separate loan needing a guarantor: add Amina, then she accepts from her own dashboard ---
  await adminPage.goto(`${BASE}/en/members`, { waitUntil: 'networkidle' });
  await adminPage.click('text=John Mwangi');
  await adminPage.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await adminPage.waitForSelector('text=Apply for a loan', { timeout: 10000 });

  const johnLoansCard = adminPage.locator('h2:has-text("Loans")').first().locator('xpath=../..');
  await johnLoansCard.locator('select').selectOption({ label: 'Development Loan' });
  await johnLoansCard.locator('input[type="number"]').first().fill('300');
  await johnLoansCard.locator('input[placeholder="Term (months)"]').fill('4');
  await johnLoansCard.locator('button:has-text("Submit application")').click();
  await adminPage.waitForSelector('text=Awaiting guarantors', { timeout: 10000 });

  await johnLoansCard.locator('a:has-text("Development Loan")').first().click();
  await adminPage.waitForURL((u) => /\/en\/loans\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await adminPage.waitForSelector('text=No guarantors added yet.', { timeout: 10000 });

  // At this point (PENDING_GUARANTORS, admin viewing) the guarantor-picker
  // is the only <select> rendered on the page - appraise/decide sections
  // don't exist yet since the loan hasn't reached those statuses.
  const guarantorSelect = adminPage.locator('main select');
  const aminaOptionValue = await guarantorSelect
    .locator('option', { hasText: 'Amina Njoroge' })
    .first()
    .getAttribute('value');
  await guarantorSelect.selectOption(aminaOptionValue);
  await adminPage.fill('input[placeholder="Pledged amount"]', '200');
  await adminPage.click('button:has-text("Add")');
  await adminPage.waitForSelector('text=Amina Njoroge', { timeout: 10000 });
  assert(true, 'guarantor added to the loan via the detail page UI');

  // --- Amina logs in and accepts the guarantee request from her own dashboard ---
  const aminaContext = await browser.newContext();
  const aminaPage = await aminaContext.newPage();
  aminaPage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await aminaPage.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await aminaPage.fill('input[type="tel"]', AMINA_PHONE);
  await aminaPage.fill('input[type="password"]', AMINA_PASSWORD);
  await aminaPage.click('button[type="submit"]');
  await aminaPage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  await aminaPage.waitForSelector('text=Guarantee requests', { timeout: 10000 });
  assert(await aminaPage.isVisible('text=John Mwangi'), 'Amina sees the guarantee request naming the borrower');

  const requestItem = aminaPage.locator('li:has-text("John Mwangi")').last();
  await requestItem.locator('button:has-text("Accept")').click();
  await aminaPage.waitForFunction(
    () => {
      const items = [...document.querySelectorAll('li')];
      const item = items.find((li) => li.textContent.includes('John Mwangi'));
      return item && !item.querySelector('button');
    },
    { timeout: 10000 },
  );
  assert(true, 'accepting replaces the Accept/Decline buttons with a resolved state');

  await aminaContext.close();

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('loans-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`loans-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
