// Smoke test: the redesigned dashboard shows real stats/activity for
// permitted data, and a visually muted "coming soon" preview grid for
// modules that aren't built yet. Requires both dev servers running +
// nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const ADMIN_PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const ADMIN_PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';
const SCRATCH = '/tmp/claude-1000/-home-muchesia/b6e8c806-dfd8-4fb6-a20f-d1f3695095d6/scratchpad';

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
  await page.fill('input[type="tel"]', ADMIN_PHONE);
  await page.fill('input[type="password"]', ADMIN_PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  // --- Live stats: real numbers, no skeletons left behind ---
  await page.waitForSelector('text=Total members', { timeout: 10000 });
  await page.waitForSelector('text=Share capital', { timeout: 10000 });
  await page.waitForSelector('text=Total savings', { timeout: 10000 });
  await page.waitForSelector('text=Ledger status', { timeout: 10000 });
  await page.waitForFunction(
    () => !document.querySelector('.animate-pulse'),
    { timeout: 10000 },
  );
  assert(await page.isVisible('text=Balanced'), 'ledger status shows a real balanced/unbalanced value');

  // --- Live activity sections ---
  await page.waitForSelector('text=Recent members', { timeout: 10000 });
  await page.waitForSelector('text=Recent ledger activity', { timeout: 10000 });

  // --- Coming-soon preview grid: present, labelled, and visually muted ---
  // Loans, Payments and Distributions used to be mock cards here too - all
  // three were removed from the preview grid once each shipped for real
  // (Phase 3, Phase 4, and Phase 5), leaving only modules that genuinely
  // aren't built yet.
  await page.waitForSelector('text=Coming soon', { timeout: 10000 });
  const previewBadgeCount = await page.locator('[data-testid="preview-badge"]').count();
  assert(previewBadgeCount === 1, `expected 1 "Preview" badge, got ${previewBadgeCount}`);
  assert(await page.isVisible('text=Governance'), 'governance preview card renders');
  assert(!(await page.isVisible('text=Dividends & interest')), 'distributions preview card no longer renders - real page exists now');

  // Contrast check: a live stat's number should render far darker than a
  // mock card's numbers, so the two are never visually confused.
  const liveColor = await page.locator('text=Total members').locator('xpath=../..').locator('p').first().evaluate(
    (el) => getComputedStyle(el).color,
  );
  const mockColor = await page.locator('dd:has-text("87%")').first().evaluate((el) => getComputedStyle(el).color);
  assert(liveColor !== mockColor, `live stat color (${liveColor}) should differ from mock card color (${mockColor})`);

  await page.screenshot({ path: `${SCRATCH}/dashboard.png`, fullPage: true });

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('dashboard-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`dashboard-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
