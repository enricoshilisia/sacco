// Visual smoke test: captures the dashboard, mobile nav drawer, members
// list, and add-member wizard at both mobile and desktop viewports.
// Screenshots land in e2e/screenshots/ (gitignored) for manual review.
//
// Requires both dev servers running + nairobi_demo seeded. Run with:
//   node e2e/responsive-check.js

const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const SCREENSHOTS_DIR = path.join(__dirname, 'screenshots');
fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

async function login(page) {
  await page.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await page.fill('input[type="tel"]', PHONE);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });
}

async function shots(viewport, label, isMobile) {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport });
  const errors = [];
  page.on('console', (msg) => {
    // Chromium logs a console "error" for every non-2xx fetch response,
    // including the expected 404 from /api/members/me/ for a pure-staff
    // login with no linked Member record - that's by-design network noise,
    // not an application bug (same filter every other e2e script uses).
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await login(page);
  await page.waitForSelector('text=Recent members', { timeout: 10000 });
  await page.screenshot({ path: path.join(SCREENSHOTS_DIR, `${label}_dashboard.png`), fullPage: true });

  if (isMobile) {
    await page.click('[aria-label="Open menu"]');
    await page.waitForSelector('[aria-label="Close menu"]', { timeout: 5000 });
    await page.screenshot({ path: path.join(SCREENSHOTS_DIR, `${label}_drawer_open.png`), fullPage: true });
  }

  await page.locator('[data-testid="nav-members"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await page.waitForSelector('text=Add member', { timeout: 10000 });
  await page.screenshot({ path: path.join(SCREENSHOTS_DIR, `${label}_members.png`), fullPage: true });

  await page.click('text=Add member');
  await page.waitForURL((u) => u.pathname === '/en/members/new', { timeout: 10000 });
  await page.screenshot({ path: path.join(SCREENSHOTS_DIR, `${label}_member_new_step1.png`), fullPage: true });

  console.log(`${label}: ${errors.length === 0 ? 'PASS' : 'FAIL'} (console errors: ${JSON.stringify(errors)})`);
  await browser.close();
  return errors.length === 0;
}

(async () => {
  const results = await Promise.all([
    shots({ width: 390, height: 844 }, 'mobile', true),
    shots({ width: 1440, height: 900 }, 'desktop', false),
  ]);
  if (results.some((ok) => !ok)) process.exit(1);
})();
