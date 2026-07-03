// Smoke test: on mobile, there's no hamburger - a docked handle bar at the
// bottom opens an app-style bottom sheet of nav cards via tap or swipe-up,
// and the sheet closes via tap-outside, its close button, or swipe-down.
// Requires both dev servers running + nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';
const SCRATCH = '/tmp/claude-1000/-home-muchesia/b6e8c806-dfd8-4fb6-a20f-d1f3695095d6/scratchpad';

// Dispatches a real TouchEvent (Playwright's Touchscreen API only supports
// tap(), not drag) so the component's onTouchStart/onTouchMove handlers -
// which is how the swipe gesture is actually implemented - fire for real.
async function touch(page, selector, type, y) {
  await page.evaluate(
    ({ selector, type, y }) => {
      const el = document.querySelector(selector);
      const rect = el.getBoundingClientRect();
      const x = rect.left + rect.width / 2;
      const touchList = type === 'touchend' ? [] : [new Touch({ identifier: 1, target: el, clientX: x, clientY: y })];
      el.dispatchEvent(
        new TouchEvent(type, { touches: touchList, targetTouches: touchList, changedTouches: touchList, bubbles: true, cancelable: true }),
      );
    },
    { selector, type, y },
  );
}

async function swipe(page, selector, fromY, toY) {
  await touch(page, selector, 'touchstart', fromY);
  await touch(page, selector, 'touchmove', toY);
  await touch(page, selector, 'touchend', toY);
}

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  // hasTouch alone gives us a real Touch/TouchEvent constructor for the
  // swipe simulation below. isMobile is deliberately omitted - combined
  // with a custom viewport (rather than a full device preset) it makes
  // Chromium report window.innerHeight larger than the requested viewport,
  // which desyncs fixed-position layout from click coordinates.
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, deviceScaleFactor: 1 });
  const page = await context.newPage();
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
  await page.waitForSelector('[data-testid="mobile-nav-handle"]', { timeout: 10000 });

  const VIEWPORT_HEIGHT = 844;
  const sheetTop = () =>
    page.locator('[data-testid="bottom-sheet"]').evaluate((el) => el.getBoundingClientRect().top);

  // --- No hamburger anywhere ---
  assert(await page.locator('button[aria-label="Open menu"]').count() === 0, 'no hamburger button exists');

  // --- Docked handle is visible; sheet starts off-screen below the fold ---
  assert(await page.locator('[data-testid="mobile-nav-handle"]').isVisible(), 'docked handle bar is visible');
  assert((await sheetTop()) >= VIEWPORT_HEIGHT - 5, 'sheet starts off-screen (below the viewport)');

  // --- Tap the handle to open the sheet ---
  await page.locator('[data-testid="mobile-nav-handle"]').click();
  await page.waitForFunction(
    (vh) => document.querySelector('[data-testid="bottom-sheet"]').getBoundingClientRect().top < vh - 100,
    VIEWPORT_HEIGHT,
    { timeout: 5000 },
  );
  assert(await page.locator('[data-testid="nav-members"]:visible').isVisible(), 'Members nav card visible in open sheet');

  // --- Nav items render as cards (icon tile + label), not list rows ---
  const cardBox = await page.locator('[data-testid="nav-members"]:visible').boundingBox();
  assert(cardBox.width < 150 && cardBox.height > 60, `nav item looks like a card, not a full-width row (got ${cardBox.width}x${cardBox.height})`);
  const gridColumns = await page
    .locator('[data-testid="nav-members"]:visible')
    .locator('xpath=..')
    .evaluate((el) => getComputedStyle(el).gridTemplateColumns.split(' ').length);
  assert(gridColumns === 3, `nav cards are laid out in a grid (got ${gridColumns} columns)`);

  // --- Tapping a card navigates and closes the sheet ---
  await page.locator('[data-testid="nav-members"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await page.waitForFunction(
    (vh) => document.querySelector('[data-testid="bottom-sheet"]').getBoundingClientRect().top >= vh - 5,
    VIEWPORT_HEIGHT,
    { timeout: 5000 },
  );

  // --- Swipe up on the handle opens the sheet ---
  await swipe(page, '[data-testid="mobile-nav-handle"]', 800, 700);
  await page.waitForFunction(
    (vh) => document.querySelector('[data-testid="bottom-sheet"]').getBoundingClientRect().top < vh - 100,
    VIEWPORT_HEIGHT,
    { timeout: 5000 },
  );

  await page.screenshot({ path: `${SCRATCH}/mobile-sheet-open.png` });

  // --- Swipe down on the open sheet closes it ---
  await swipe(page, '[data-testid="bottom-sheet"]', 100, 220);
  await page.waitForFunction(
    (vh) => document.querySelector('[data-testid="bottom-sheet"]').getBoundingClientRect().top >= vh - 5,
    VIEWPORT_HEIGHT,
    { timeout: 5000 },
  );

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('mobile-nav-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`mobile-nav-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
