// Smoke test: the top bar and sidebar are fixed/static while only the main
// content area scrolls, and the top bar carries language/profile/logout.
// Requires both dev servers running + nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';
const SCRATCH = '/tmp/claude-1000/-home-muchesia/b6e8c806-dfd8-4fb6-a20f-d1f3695095d6/scratchpad';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await page.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await page.fill('input[type="tel"]', PHONE);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });
  await page.waitForSelector('[data-testid="nav-dashboard"]:visible', { timeout: 10000 });

  // --- Top bar carries language, profile, logout ---
  assert(await page.locator('header select[aria-label="Language"]').count() > 0, 'language switcher is in the top bar');
  assert(await page.locator('header').getByText('Asha Kariuki').count() > 0, 'profile name is in the top bar');
  assert(await page.locator('header button[aria-label="Log out"]').count() > 0, 'logout button is in the top bar');

  // --- Sidebar and top bar positions before scrolling ---
  const headerBoxBefore = await page.locator('header').boundingBox();
  const asideBoxBefore = await page.locator('aside:visible').boundingBox();

  await page.screenshot({ path: `${SCRATCH}/layout-top.png` });

  // --- Scroll the main content area; bars must not move ---
  await page.locator('main').evaluate((el) => el.scrollTo(0, 400));
  await page.waitForTimeout(200);

  const headerBoxAfter = await page.locator('header').boundingBox();
  const asideBoxAfter = await page.locator('aside:visible').boundingBox();
  const mainScrollTop = await page.locator('main').evaluate((el) => el.scrollTop);

  assert(mainScrollTop > 0, 'main content actually scrolled');
  assert(headerBoxBefore.y === headerBoxAfter.y, 'top bar did not move while content scrolled');
  assert(asideBoxBefore.y === asideBoxAfter.y, 'sidebar did not move while content scrolled');
  assert(asideBoxBefore.x === asideBoxAfter.x, 'sidebar stayed in place horizontally too');

  await page.screenshot({ path: `${SCRATCH}/layout-scrolled.png` });

  // --- Top bar's brand zone lines up with the sidebar (same width/border) ---
  const brandZoneWidth = await page.locator('header > div').first().evaluate((el) => el.getBoundingClientRect().width);
  const sidebarWidth = asideBoxBefore.width;
  assert(Math.abs(brandZoneWidth - sidebarWidth) < 1, 'top bar brand zone width matches sidebar width');

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('layout-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`layout-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
