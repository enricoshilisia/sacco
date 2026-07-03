// Smoke test: the sidebar only shows nav items the logged-in role actually
// has permission for, and directly visiting a hidden route still 403s
// (nav hiding is a UX nicety on top of the real, page-level RBAC check -
// never a substitute for it). Requires both dev servers running +
// nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const ADMIN_PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

const TELLER_PHONE = '+254733444555';
const TELLER_PASSWORD = 'TellerPass123!';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const adminPage = await browser.newPage();
  const errors = [];
  adminPage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  // --- SuperAdmin sees every nav item ---
  await adminPage.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await adminPage.fill('input[type="tel"]', ADMIN_PHONE);
  await adminPage.fill('input[type="password"]', ADMIN_PASSWORD);
  await adminPage.click('button[type="submit"]');
  await adminPage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });
  await adminPage.waitForSelector('[data-testid="nav-dashboard"]:visible', { timeout: 10000 });

  for (const item of ['dashboard', 'members', 'accounting', 'settings']) {
    assert(
      await adminPage.locator(`[data-testid="nav-${item}"]:visible`).count() > 0,
      `SuperAdmin sees nav-${item}`,
    );
  }

  // --- Invite a Teller (members.view/deposit/withdraw only - no
  // accounting.* or configuration.*/accesscontrol.* permissions) ---
  await adminPage.locator('[data-testid="nav-settings"]:visible').click();
  await adminPage.waitForURL((u) => u.pathname === '/en/settings', { timeout: 10000 });
  await adminPage.click('button:has-text("Staff")');
  await adminPage.waitForSelector('text=Staff roster', { timeout: 10000 });

  await adminPage.fill('label:has-text("First name") input', 'Wanjiru');
  await adminPage.fill('label:has-text("Last name") input', 'Kamau');
  await adminPage.fill('label:has-text("Phone number") input', TELLER_PHONE);
  await adminPage.selectOption('label:has-text("Role") select', { label: 'Teller' });
  const [inviteResponse] = await Promise.all([
    adminPage.waitForResponse((r) => r.url().includes('/api/tenant/staff/invites/') && r.request().method() === 'POST'),
    adminPage.click('button:has-text("Create invite")'),
  ]);
  const invite = await inviteResponse.json();

  // --- Accept as the new Teller in a fresh, unauthenticated context ---
  const tellerContext = await browser.newContext();
  const tellerPage = await tellerContext.newPage();
  tellerPage.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await tellerPage.goto(`${BASE}/en${invite.invite_path}`, { waitUntil: 'networkidle' });
  await tellerPage.waitForSelector('text=Set up your staff account', { timeout: 10000 });
  await tellerPage.fill('input[type="password"]', TELLER_PASSWORD);
  await tellerPage.click('button:has-text("Set up account")');
  await tellerPage.waitForSelector("text=You're all set", { timeout: 10000 });
  await tellerPage.click('text=Go to sign in');
  await tellerPage.waitForURL((u) => u.pathname === '/en/login', { timeout: 10000 });

  await tellerPage.fill('input[type="tel"]', TELLER_PHONE);
  await tellerPage.fill('input[type="password"]', TELLER_PASSWORD);
  await tellerPage.click('button[type="submit"]');
  await tellerPage.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });
  await tellerPage.waitForSelector('[data-testid="nav-dashboard"]:visible', { timeout: 10000 });

  // --- Teller's sidebar: Dashboard + Members only ---
  assert(await tellerPage.locator('[data-testid="nav-dashboard"]:visible').count() > 0, 'Teller sees nav-dashboard');
  assert(await tellerPage.locator('[data-testid="nav-members"]:visible').count() > 0, 'Teller sees nav-members');
  assert(await tellerPage.locator('[data-testid="nav-accounting"]').count() === 0, 'Teller does NOT see nav-accounting');
  assert(await tellerPage.locator('[data-testid="nav-settings"]').count() === 0, 'Teller does NOT see nav-settings');

  // --- Defense in depth: direct navigation to a hidden route still 403s ---
  await tellerPage.goto(`${BASE}/en/accounting`, { waitUntil: 'networkidle' });
  await tellerPage.waitForSelector("text=You don't have permission to view accounting.", { timeout: 10000 });

  await tellerPage.goto(`${BASE}/en/settings`, { waitUntil: 'networkidle' });
  await tellerPage.waitForSelector("text=You don't have permission to view settings.", { timeout: 10000 });

  await tellerContext.close();

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('nav-permissions-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`nav-permissions-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
