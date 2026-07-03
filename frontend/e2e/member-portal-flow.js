// Smoke test: staff invites an existing member to the self-service portal
// from the member's detail page, the member accepts as a brand-new
// unauthenticated user, and their dashboard shows a "My account" section
// with their own shares/savings - not the staff dashboard. Requires both
// dev servers running + nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const ADMIN_PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

const MEMBER_PASSWORD = 'GracePortal123!';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const adminPage = await browser.newPage();
  const errors = [];
  adminPage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  // --- Admin: open Grace Wambui's member detail page ---
  await adminPage.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await adminPage.fill('input[type="tel"]', ADMIN_PHONE);
  await adminPage.fill('input[type="password"]', ADMIN_PASSWORD);
  await adminPage.click('button[type="submit"]');
  await adminPage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  await adminPage.locator('[data-testid="nav-members"]:visible').click();
  await adminPage.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await adminPage.click('text=Grace Wambui');
  await adminPage.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await adminPage.waitForSelector('text=Portal access', { timeout: 10000 });

  assert(
    await adminPage.isVisible("text=This member doesn't have self-service login access yet."),
    'portal access starts as "not invited"',
  );

  const [inviteResponse] = await Promise.all([
    adminPage.waitForResponse((r) => r.url().includes('/portal-invite/') && r.request().method() === 'POST'),
    adminPage.click('button:has-text("Invite to portal")'),
  ]);
  const invite = await inviteResponse.json();
  assert(invite.status === 'pending', 'invite created as pending');
  await adminPage.waitForSelector('button:has-text("Copy setup link")', { timeout: 10000 });

  // --- Accept the invite as a brand-new, unauthenticated user ---
  const memberContext = await browser.newContext();
  const memberPage = await memberContext.newPage();
  memberPage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await memberPage.goto(`${BASE}/en${invite.invite_path}`, { waitUntil: 'networkidle' });
  await memberPage.waitForSelector('text=Set up your member account', { timeout: 10000 });
  assert(await memberPage.isVisible('text=Grace Wambui'), 'accept page shows the invited member name');

  await memberPage.fill('input[type="password"]', MEMBER_PASSWORD);
  const [acceptResponse] = await Promise.all([
    memberPage.waitForResponse((r) => r.url().includes('/accept/') && r.request().method() === 'POST'),
    memberPage.click('button:has-text("Set up account")'),
  ]);
  // Read Grace's phone from the accept response rather than hardcoding it -
  // this demo tenant's seed data has needed a phone-number fix mid-session
  // before (two members originally shared one number).
  const gracePhone = (await acceptResponse.json()).user.phone_number;
  await memberPage.waitForSelector("text=You're all set", { timeout: 10000 });
  await memberPage.click('text=Go to sign in');
  await memberPage.waitForURL((u) => u.pathname === '/en/login', { timeout: 10000 });

  // --- Log in as Grace, confirm the self-service dashboard ---
  await memberPage.fill('input[type="tel"]', gracePhone);
  await memberPage.fill('input[type="password"]', MEMBER_PASSWORD);
  await memberPage.click('button[type="submit"]');
  await memberPage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  await memberPage.waitForSelector('text=My account', { timeout: 10000 });
  assert(await memberPage.isVisible('text=Share capital'), 'self-service dashboard shows share capital');

  // --- Member role sees no staff nav items ---
  await memberPage.waitForSelector('[data-testid="nav-dashboard"]:visible', { timeout: 10000 });
  assert(await memberPage.locator('[data-testid="nav-members"]').count() === 0, 'no Members nav item for an ordinary member');
  assert(await memberPage.locator('[data-testid="nav-accounting"]').count() === 0, 'no Accounting nav item for an ordinary member');
  assert(await memberPage.locator('[data-testid="nav-payments"]').count() === 0, 'no Payments nav item for an ordinary member');
  assert(await memberPage.locator('[data-testid="nav-settings"]').count() === 0, 'no Settings nav item for an ordinary member');

  await memberContext.close();

  // --- Back in the admin session: portal access now shows as linked ---
  await adminPage.reload({ waitUntil: 'networkidle' });
  await adminPage.waitForSelector('text=This member can log in and view their own account.', { timeout: 10000 });

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('member-portal-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`member-portal-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
