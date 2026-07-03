// Smoke test: share contribution, savings deposit/withdraw on a member's
// detail page, and the /accounting trial balance + journal pages.
// Requires both dev servers running + nairobi_demo seeded.

const { chromium } = require('playwright');

const BASE = process.env.E2E_BASE_URL ?? 'http://nairobi.localhost:3000';
const PHONE = process.env.E2E_ADMIN_PHONE ?? '+254700000001';
const PASSWORD = process.env.E2E_ADMIN_PASSWORD ?? 'DemoPass123!';

async function run() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const errors = [];
  page.on('console', (msg) => {
    // Chromium logs a console "error" for every non-2xx fetch response,
    // including the intentional 400 from the over-withdrawal check below -
    // that's expected network noise, not an application bug.
    if (msg.type() === 'error' && !msg.text().startsWith('Failed to load resource')) {
      errors.push(msg.text());
    }
  });

  await page.goto(`${BASE}/en/login`, { waitUntil: 'networkidle' });
  await page.fill('input[type="tel"]', PHONE);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => u.pathname === '/en/dashboard', { timeout: 10000 });

  // --- Open member detail page ---
  await page.locator('[data-testid="nav-members"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/members', { timeout: 10000 });
  await page.click('text=John Mwangi');
  await page.waitForURL((u) => /\/en\/members\/[0-9a-f-]+$/.test(u.pathname), { timeout: 10000 });
  await page.waitForSelector('text=Shares', { timeout: 10000 });

  // --- Contribute shares ---
  const sharesCard = page.locator('h2:has-text("Shares")').locator('xpath=../..');
  const balanceBefore = (await sharesCard.locator('dd').innerText()).trim();
  await sharesCard.locator('input[type="number"]').fill('5000');
  await sharesCard.locator('button:has-text("Contribute")').click();
  await page.waitForFunction(
    (prevText) => {
      const heading = [...document.querySelectorAll('h2')].find((h) => h.textContent === 'Shares');
      if (!heading) return false;
      const card = heading.closest('div').parentElement;
      const dd = card.querySelector('dd');
      return dd && dd.textContent.trim() !== prevText;
    },
    balanceBefore,
    { timeout: 10000 },
  );
  assert(true, 'share balance updated after contribution');

  // --- Open a new savings account via first-time deposit ---
  const savingsCard = page.locator('h2:has-text("Savings")').locator('xpath=../..');
  const hasOpenSection = await savingsCard.locator('text=Open a new savings account').count();
  if (hasOpenSection > 0) {
    await savingsCard.locator('select').selectOption({ index: 1 });
    await savingsCard.locator('text=Open a new savings account').locator('xpath=..').locator('input[type="number"]').fill('2000');
    await savingsCard.locator('text=Open a new savings account').locator('xpath=..').locator('button:has-text("Deposit")').click();
    await page.waitForSelector('text=Open a new savings account', { state: 'hidden', timeout: 10000 }).catch(() => {});
  }
  await page.waitForSelector('.rounded-lg.border.border-primary-100', { timeout: 10000 });

  const accountBox = page.locator('.rounded-lg.border.border-primary-100').first();
  const balanceAfterOpen = (await accountBox.locator('p.font-mono').innerText()).trim();

  // --- Attempt an over-withdrawal, expect an inline error ---
  const numberInputs = accountBox.locator('input[type="number"]');
  await numberInputs.nth(1).fill('999999');
  await accountBox.locator('button:has-text("Withdraw")').click();
  await page.waitForSelector('text=exceeds available balance', { timeout: 10000 });
  assert(true, 'over-withdrawal error surfaced in the UI');

  // --- Valid withdrawal ---
  await numberInputs.nth(1).fill('500');
  await accountBox.locator('button:has-text("Withdraw")').click();
  await page.waitForFunction(
    (prevText) => {
      const box = document.querySelector('.rounded-lg.border.border-primary-100');
      const bal = box && box.querySelector('p.font-mono');
      return bal && bal.textContent.trim() !== prevText;
    },
    balanceAfterOpen,
    { timeout: 10000 },
  );
  assert(true, 'savings balance updated after valid withdrawal');

  // --- Accounting page ---
  await page.locator('[data-testid="nav-accounting"]:visible').click();
  await page.waitForURL((u) => u.pathname === '/en/accounting', { timeout: 10000 });
  await page.waitForSelector('text=Balanced', { timeout: 10000 });
  assert(await page.isVisible('text=Balanced'), 'trial balance shows balanced');

  await page.click('button:has-text("Journal")');
  await page.waitForSelector('text=JE-', { timeout: 10000 });
  const entryCount = await page.locator('p.font-mono.text-sm.font-semibold').count();
  assert(entryCount > 0, 'journal entries listed');

  assert(errors.length === 0, `no console errors (got: ${JSON.stringify(errors)})`);

  await browser.close();
  console.log('savings-flow: PASS');
}

function assert(condition, message) {
  if (!condition) throw new Error(`savings-flow: FAIL - ${message}`);
}

run().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
