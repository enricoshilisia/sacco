// Smoke test: settings tabs, SACCO logo upload, member photo upload.
// Requires both dev servers running + nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';
const SCRATCH = '/tmp/claude-1000/-home-muchesia/b6e8c806-dfd8-4fb6-a20f-d1f3695095d6/scratchpad';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const errors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  await page.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await page.fill('input[type="tel"]', PHONE);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  // --- Settings tabs + logo upload ---
  await page.locator('[data-testid="nav-settings"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/settings', { timeout: 10000 });
  await page.waitForSelector('text=SACCO name', { timeout: 10000 });

  assert(await page.isVisible('text=SACCO name'), 'SACCO details tab active by default');
  assert(!(await page.isVisible('text=Accepted ID types')), 'numbering tab content hidden initially');

  await page.click('button:has-text("Member numbering")');
  await page.waitForSelector('text=Accepted ID types', { timeout: 5000 });
  assert(!(await page.isVisible('text=SACCO name')), 'sacco tab content hidden after switching');

  await page.click('button:has-text("SACCO details")');
  await page.waitForSelector('text=SACCO name', { timeout: 5000 });

  await page.setInputFiles('input[type="file"]', `${SCRATCH}/test-logo.png`);
  await page.click('button:has-text("Save changes")');
  await page.waitForSelector('text=Saved', { timeout: 10000 });

  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForSelector('text=SACCO name', { timeout: 10000 });
  const logoImg = await page.locator('button:has-text("Change logo") >> xpath=../.. >> img').count();
  assert(logoImg > 0, 'logo image renders after reload');

  // The top bar's brand zone should also pick up the new logo.
  const topBarLogo = await page.locator('header img').count();
  assert(topBarLogo > 0, 'top bar shows uploaded logo');

  // --- Member photo upload ---
  await page.locator('[data-testid="nav-members"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await page.waitForSelector('text=Add member', { timeout: 10000 });
  await page.click('text=John Mwangi');
  await page.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=Category', { timeout: 10000 });

  await page.setInputFiles('input[type="file"]', `${SCRATCH}/test-photo.png`);
  await page.waitForTimeout(1500); // upload is fire-and-forget from the click target, give it a moment
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForSelector('text=Category', { timeout: 10000 });
  const memberPhoto = await page.locator('main img').count();
  assert(memberPhoto > 0, 'member photo renders after reload');

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('uploads-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`uploads-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
