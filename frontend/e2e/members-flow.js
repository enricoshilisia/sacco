// Smoke test: log in as a SACCO SuperAdmin, add a member with a next-of-kin,
// and verify their KYC. Exercises RBAC end-to-end (members.create,
// members.view, members.kyc_verify against the seeded SuperAdmin role).
//
// Requires both dev servers running (backend :8000, frontend :3000) and the
// nairobi_demo tenant seeded per README.md. Run with:
//   node e2e/members-flow.js

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const consoleErrors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });

  await page.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await page.fill('input[type="tel"]', PHONE);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  await page.click('text=View members');
  await page.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await page.waitForSelector('text=Add member', { timeout: 10000 });

  await page.click('text=Add member');
  await page.waitForURL((u) => u.pathname === '/en/members/new', { timeout: 10000 });

  const idNumber = String(Date.now()).slice(-8); // unique per run

  // Step 1: personal details
  await page.getByLabel('First name').fill('E2E');
  await page.getByLabel('Last name').fill('Smoke');
  await page.click('button:has-text("Next")');

  // Step 2: ID & contact
  await page.getByLabel('ID number').fill(idNumber);
  await page.getByLabel('Phone').fill('+254700000999');
  await page.getByLabel('Email').fill('e2e-smoke@example.com');
  await page.getByLabel('Physical address').fill('Test Address');
  await page.click('button:has-text("Next")');

  // Step 3: next of kin, then submit
  await page.click('text=Add person');
  await page.getByPlaceholder('Full name').fill('E2E Kin');
  await page.getByPlaceholder('Relationship').fill('sibling');

  await page.click('button:has-text("Save member")');
  await page.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=Verify KYC', { timeout: 10000 });

  const detailText = await page.textContent('main');
  assert(detailText.includes('E2E') && detailText.includes('Smoke'), 'member name renders on detail page');
  assert(detailText.includes('E2E Kin'), 'next-of-kin renders on detail page');

  await page.click('text=Verify KYC');
  await page.waitForSelector('text=Verified', { timeout: 5000 });

  assert(consoleErrors.length === 0, `no console errors (got: ${JSON.stringify(consoleErrors)})`);

  await browser.close();
  console.log('members-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`members-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
