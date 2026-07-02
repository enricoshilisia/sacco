// Smoke test: log in, open Settings, change the member-number style,
// verify the preview updates, save, then create a member and confirm it
// picked up the newly configured numbering style. Resets to defaults after.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

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

  await page.locator('[data-testid="nav-settings"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/settings', { timeout: 10000 });
  await page.waitForSelector('text=Member numbering', { timeout: 10000 });

  const prefixInput = page.getByLabel('Prefix');
  const paddingInput = page.getByLabel('Digits');
  await prefixInput.fill('E2E-');
  await paddingInput.fill('3');

  const preview = await page.textContent('[data-testid="member-number-preview"]');
  assert(preview.includes('E2E-'), `preview updates live (got: ${preview})`);

  await page.click('button:has-text("Save changes")');
  await page.waitForSelector('text=Saved', { timeout: 5000 });

  // Reload to confirm it persisted server-side, not just local state.
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForSelector('text=Member numbering', { timeout: 10000 });
  const persistedPrefix = await page.getByLabel('Prefix').inputValue();
  assert(persistedPrefix === 'E2E-', `prefix persisted after reload (got: ${persistedPrefix})`);

  // Create a member and confirm the new number style is actually used.
  await page.locator('[data-testid="nav-members"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await page.click('text=Add member');
  await page.waitForURL((u) => u.pathname === '/en/members/new', { timeout: 10000 });

  const idNumber = String(Date.now()).slice(-8);
  await page.getByLabel('First name').fill('Settings');
  await page.getByLabel('Last name').fill('Test');
  await page.click('button:has-text("Next")');
  await page.getByLabel('ID number').fill(idNumber);
  await page.getByLabel('Phone').fill('+254700111222');
  await page.click('button:has-text("Next")');
  await page.click('button:has-text("Save member")');

  await page.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=Category', { timeout: 10000 });
  const detailText = await page.textContent('main');
  assert(/E2E-\d{3}/.test(detailText), `new member uses configured style (got: ${detailText.slice(0, 100)})`);

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('settings-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`settings-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
