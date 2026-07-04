// Smoke test: a self-service member (no staff permissions) sees a Profile
// nav item, lands on a /profile page showing their own KYC-sourced member
// details as read-only, and can edit + save their contact details (phone,
// email, physical address) via PATCH /api/members/me/, plus change their
// own password via POST /api/auth/me/change-password/ - the third piece of
// "make the member dashboard have their menus" (Loans, Savings, and now
// Profile), following the "cards too big, no way to change password"
// follow-up. Also confirms the Dashboard no longer shows SACCO-wide stats or
// the old "Your profile"/"SACCO profile" cards to a self-service member.
// Requires both dev servers running + nairobi_demo seeded, with Amina
// Njoroge already holding portal access (phone +254788112233 /
// AminaPass123!).

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

  // --- Dashboard is a real dashboard for a self-service member: no
  // SACCO-wide stats/profile cards, just their own account + loans ---
  await page.waitForSelector('text=My account', { timeout: 10000 });
  assert(await page.locator('text=Total members').count() === 0, 'self-service member does not see Total members stat');
  assert(await page.locator('text=Recent members').count() === 0, 'self-service member does not see Recent members');
  assert(await page.locator('text=SACCO profile').count() === 0, 'self-service member does not see the old SACCO profile card');
  assert(await page.locator('text=Your profile').count() === 0, 'self-service member does not see the old Your profile card');

  // --- Profile nav item is visible and navigates to /profile ---
  await page.waitForSelector('[data-testid="nav-profile"]:visible', { timeout: 10000 });
  await page.locator('[data-testid="nav-profile"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/profile', { timeout: 10000 });
  await page.waitForSelector('text=Amina Njoroge', { timeout: 10000 });
  await page.waitForSelector('text=Change password', { timeout: 10000 });

  // --- Contact details are editable; identity fields are not ---
  const memberCard = page.locator('form').filter({ has: page.locator('text=Physical address') });
  await memberCard.waitFor({ timeout: 10000 });
  assert(await memberCard.locator('input').count() === 3, 'exactly 3 editable inputs (phone, email, address)');

  const addressInput = page.locator('label:has-text("Physical address") input');
  const before = await addressInput.inputValue();
  const updated = `${before} (updated ${Date.now()})`;
  await addressInput.fill(updated);

  const [patchResponse] = await Promise.all([
    page.waitForResponse((r) => r.url().endsWith('/api/members/me/') && r.request().method() === 'PATCH'),
    memberCard.locator('button:has-text("Save changes")').click(),
  ]);
  assert(patchResponse.status() === 200, 'PATCH /api/members/me/ succeeded');
  await memberCard.locator('button:has-text("Saved")').waitFor({ timeout: 10000 });

  await page.reload({ waitUntil: 'networkidle' });
  assert((await addressInput.inputValue()) === updated, 'edited address persisted across reload');

  // Revert so repeated runs don't pile up address changes.
  await addressInput.fill(before);
  await Promise.all([
    page.waitForResponse((r) => r.url().endsWith('/api/members/me/') && r.request().method() === 'PATCH'),
    memberCard.locator('button:has-text("Save changes")').click(),
  ]);
  await memberCard.locator('button:has-text("Saved")').waitFor({ timeout: 10000 });

  // --- Change password: wrong current password is rejected, correct one
  // succeeds, then revert so repeated runs keep working with the same
  // fixture credentials. ---
  const passwordCard = page.locator('form').filter({ has: page.locator('text=Change password') });
  await passwordCard.locator('input').nth(0).fill('WrongPassword1!');
  await passwordCard.locator('input').nth(1).fill('AminaPassNew1!');
  await passwordCard.locator('input').nth(2).fill('AminaPassNew1!');
  const [rejected] = await Promise.all([
    page.waitForResponse((r) => r.url().endsWith('/api/auth/me/change-password/')),
    passwordCard.locator('button:has-text("Change password")').click(),
  ]);
  assert(rejected.status() === 400, 'wrong current password is rejected with 400');
  await page.waitForSelector('text=Current password is incorrect.', { timeout: 10000 });

  await passwordCard.locator('input').nth(0).fill(AMINA_PASSWORD);
  const [accepted] = await Promise.all([
    page.waitForResponse((r) => r.url().endsWith('/api/auth/me/change-password/')),
    passwordCard.locator('button:has-text("Change password")').click(),
  ]);
  assert(accepted.status() === 204, 'correct current password change succeeds');
  await passwordCard.locator('button:has-text("Saved")').waitFor({ timeout: 10000 });

  // Revert to the fixture password so the next run (and every other script
  // using Amina's credentials) keeps working.
  await passwordCard.locator('input').nth(0).fill('AminaPassNew1!');
  await passwordCard.locator('input').nth(1).fill(AMINA_PASSWORD);
  await passwordCard.locator('input').nth(2).fill(AMINA_PASSWORD);
  const [reverted] = await Promise.all([
    page.waitForResponse((r) => r.url().endsWith('/api/auth/me/change-password/')),
    passwordCard.locator('button:has-text("Change password")').click(),
  ]);
  assert(reverted.status() === 204, 'password reverted back to the fixture value');

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('member-self-service-profile-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`member-self-service-profile-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
