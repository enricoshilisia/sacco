// Smoke test: invite a staff member from Settings > Staff, accept the
// invite as a brand-new (unauthenticated) user, log in with the new
// account, confirm role-appropriate access, then revoke a throwaway
// invite. Requires both dev servers running + nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const ADMIN_PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

const STAFF_PHONE = '+254722333444';
const STAFF_PASSWORD = 'PeterPass123!';
const REVOKE_PHONE = '+254799111222';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const adminPage = await browser.newPage();
  // nairobi.localhost is a secure context in Chromium (localhost + its
  // subdomains are always "potentially trustworthy"), so navigator.clipboard
  // would actually be defined here - but the real bug report came from a
  // plain-HTTP nip.io host, where it's undefined. Force that condition so
  // this test actually exercises the execCommand fallback, regardless of
  // which host the suite happens to run against.
  await adminPage.addInitScript(() => {
    Object.defineProperty(navigator, 'clipboard', { value: undefined, configurable: true });
  });
  const errors = [];
  adminPage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  // --- Log in as SuperAdmin, open Settings > Staff ---
  await adminPage.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await adminPage.fill('input[type="tel"]', ADMIN_PHONE);
  await adminPage.fill('input[type="password"]', ADMIN_PASSWORD);
  await adminPage.click('button[type="submit"]');
  await adminPage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  await adminPage.locator('[data-testid="nav-settings"]:visible').click();
  await adminPage.waitForURL((u) => u.pathname === '/en/settings', { timeout: 10000 });
  await adminPage.click('button:has-text("Staff")');
  await adminPage.waitForSelector('text=Staff roster', { timeout: 10000 });
  assert(await adminPage.isVisible('text=Asha'), 'existing SuperAdmin visible in roster');

  // --- Invite a new Accountant ---
  await adminPage.fill('label:has-text("First name") input', 'Peter');
  await adminPage.fill('label:has-text("Last name") input', 'Njoroge');
  await adminPage.fill('label:has-text("Phone number") input', STAFF_PHONE);
  await adminPage.fill('label:has-text("Job title") input', 'Finance Officer');
  await adminPage.selectOption('label:has-text("Role") select', { label: 'Accountant' });

  const [inviteResponse] = await Promise.all([
    adminPage.waitForResponse((r) => r.url().includes('/api/tenant/staff/invites/') && r.request().method() === 'POST'),
    adminPage.click('button:has-text("Create invite")'),
  ]);
  const invite = await inviteResponse.json();
  assert(invite.status === 'pending', 'invite created as pending');

  await adminPage.waitForSelector('text=Peter Njoroge', { timeout: 10000 });
  assert(await adminPage.isVisible('text=Peter Njoroge'), 'new invite appears in pending list');

  // --- Copy the setup link (regression check: navigator.clipboard is
  // undefined over plain HTTP on non-localhost hosts like nip.io, so this
  // must fall back gracefully instead of throwing) ---
  await adminPage
    .locator('li:has-text("Peter Njoroge")')
    .locator('button:has-text("Copy setup link")')
    .click();
  await adminPage.waitForSelector('li:has-text("Peter Njoroge") button:has-text("Copied")', { timeout: 5000 });

  // --- Accept the invite as a brand-new, unauthenticated user ---
  const inviteContext = await browser.newContext();
  const invitePage = await inviteContext.newPage();
  invitePage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await invitePage.goto(`${BASE}/en${invite.invite_path}`, { waitUntil: 'networkidle' });
  await invitePage.waitForSelector('text=Set up your staff account', { timeout: 10000 });
  assert(await invitePage.isVisible('text=Accountant'), 'accept page shows the invited role');
  assert(await invitePage.isVisible('text=Nairobi Demo SACCO'), 'accept page shows the SACCO name');

  await invitePage.fill('input[type="password"]', STAFF_PASSWORD);
  await invitePage.click('button:has-text("Set up account")');
  await invitePage.waitForSelector("text=You're all set", { timeout: 10000 });

  await invitePage.click('text=Go to sign in');
  await invitePage.waitForURL((u) => u.pathname === '/en/login', { timeout: 10000 });

  // --- Log in as the new staff member, confirm role-appropriate access ---
  await invitePage.fill('input[type="tel"]', STAFF_PHONE);
  await invitePage.fill('input[type="password"]', STAFF_PASSWORD);
  await invitePage.click('button[type="submit"]');
  await invitePage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  await invitePage.locator('[data-testid="nav-accounting"]:visible').click();
  await invitePage.waitForURL((u) => u.pathname === '/en/accounting', { timeout: 10000 });
  await invitePage.waitForSelector('text=Balanced', { timeout: 10000 });
  assert(await invitePage.isVisible('text=Balanced'), 'new Accountant can view the trial balance');

  await inviteContext.close();

  // --- Back in the admin session: the accepted invite is off the pending list ---
  await adminPage.reload({ waitUntil: 'networkidle' });
  await adminPage.click('button:has-text("Staff")');
  await adminPage.waitForSelector('text=Staff roster', { timeout: 10000 });
  await adminPage.waitForSelector('text=Peter Njoroge', { timeout: 10000 }); // now in the roster table
  const pendingSectionText = await adminPage.locator('text=Pending invites').locator('xpath=..').innerText();
  assert(!pendingSectionText.includes('Peter Njoroge'), 'accepted invite no longer listed as pending');

  // --- Create and revoke a throwaway invite ---
  await adminPage.fill('label:has-text("First name") input', 'Temp');
  await adminPage.fill('label:has-text("Last name") input', 'Person');
  await adminPage.fill('label:has-text("Phone number") input', REVOKE_PHONE);
  await adminPage.selectOption('label:has-text("Role") select', { label: 'Teller' });
  await Promise.all([
    adminPage.waitForResponse((r) => r.url().includes('/api/tenant/staff/invites/') && r.request().method() === 'POST'),
    adminPage.click('button:has-text("Create invite")'),
  ]);
  await adminPage.waitForSelector('text=Temp Person', { timeout: 10000 });

  await adminPage
    .locator('li:has-text("Temp Person")')
    .locator('button:has-text("Revoke")')
    .click();
  await adminPage.waitForSelector('text=Temp Person', { state: 'hidden', timeout: 10000 });

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('staff-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`staff-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
