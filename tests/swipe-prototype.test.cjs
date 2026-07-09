const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');

const chromeExecutable =
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const prototypeUrl = pathToFileURL(
  path.resolve(__dirname, '..', 'wavepoint-swipe-prototype.html')
).href;

async function openPrototype(viewport = { width: 390, height: 844 }) {
  const browser = await chromium.launch({
    executablePath: chromeExecutable,
    headless: true
  });
  const page = await browser.newPage({ viewport });
  const pageErrors = [];

  page.on('pageerror', (error) => pageErrors.push(error.message));
  await page.goto(prototypeUrl);

  return { browser, page, pageErrors };
}

test('supports remove, undo, keep, and keyboard decisions', async () => {
  const { browser, page, pageErrors } = await openPrototype();

  try {
    const firstTitle = await page.locator('[data-track-title]').textContent();

    await page.getByRole('button', { name: /stage .* for removal/i }).click();
    assert.equal(await page.locator('[data-staged-count]').textContent(), '1');
    assert.notEqual(await page.locator('[data-track-title]').textContent(), firstTitle);

    await page.getByRole('button', { name: /undo/i }).click();
    assert.equal(await page.locator('[data-track-title]').textContent(), firstTitle);
    assert.equal(await page.locator('[data-staged-count]').textContent(), '0');

    await page.keyboard.press('ArrowRight');
    assert.notEqual(await page.locator('[data-track-title]').textContent(), firstTitle);
    await page.keyboard.press('z');
    assert.equal(await page.locator('[data-track-title]').textContent(), firstTitle);

    assert.deepEqual(pageErrors, []);
  } finally {
    await browser.close();
  }
});

test('supports pointer removal and shows sprint results', async () => {
  const { browser, page, pageErrors } = await openPrototype();

  try {
    const card = page.locator('[data-swipe-card]');
    await card.scrollIntoViewIfNeeded();
    const box = await card.boundingBox();
    assert.ok(box, 'swipe card should be visible');

    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.down();
    await page.mouse.move(box.x + 20, box.y + box.height / 2, { steps: 8 });
    await page.mouse.up();

    assert.equal(await page.locator('[data-staged-count]').textContent(), '1');

    while (await page.locator('[data-swipe-card]').isVisible()) {
      await page.getByRole('button', { name: /keep .* in liked songs/i }).click();
    }

    await assert.doesNotReject(
      page.getByRole('heading', { name: /sprint cleared/i }).waitFor()
    );
    assert.equal(await page.locator('[data-result-decisions]').textContent(), '6');
    assert.equal(await page.locator('[data-result-removals]').textContent(), '1');
    assert.equal(await page.locator('[data-result-cleared]').count(), 1);
    assert.equal(await page.locator('[data-result-cleared]').textContent(), '4 min');
    assert.deepEqual(pageErrors, []);
  } finally {
    await browser.close();
  }
});

test('springs a subthreshold drag back into place', async () => {
  const { browser, page, pageErrors } = await openPrototype();

  try {
    const card = page.locator('[data-swipe-card]');
    await card.scrollIntoViewIfNeeded();
    const box = await card.boundingBox();
    assert.ok(box, 'swipe card should be visible');

    const centerX = box.x + box.width / 2;
    const centerY = box.y + box.height / 2;
    await page.mouse.move(centerX, centerY);
    await page.mouse.down();
    await page.mouse.move(centerX + 60, centerY, { steps: 4 });
    await page.mouse.up();

    assert.notEqual(
      await card.evaluate((element) => getComputedStyle(element).transitionDuration),
      '0s'
    );
    await page.waitForTimeout(280);
    assert.equal(
      await card.evaluate((element) => getComputedStyle(element).transform),
      'none'
    );
    assert.equal(await page.locator('[data-progress-label]').textContent(), '0 / 6 decided');
    assert.deepEqual(pageErrors, []);
  } finally {
    await browser.close();
  }
});

test('stays accessible and avoids horizontal overflow', async () => {
  for (const viewport of [
    { width: 390, height: 844 },
    { width: 768, height: 900 },
    { width: 1440, height: 1000 }
  ]) {
    const { browser, page, pageErrors } = await openPrototype(viewport);

    try {
      const dimensions = await page.evaluate(() => ({
        scrollWidth: document.documentElement.scrollWidth,
        clientWidth: document.documentElement.clientWidth
      }));
      assert.ok(
        dimensions.scrollWidth <= dimensions.clientWidth,
        `page should not overflow at ${viewport.width}px`
      );

      assert.equal(await page.locator('[role="status"][aria-live="polite"]').count(), 1);
      assert.equal(
        await page.locator('[role="status"]').evaluate(
          (element) => getComputedStyle(element).position
        ),
        'absolute'
      );
      assert.equal(
        await page.locator('[data-album-art]').getAttribute('preserveAspectRatio'),
        'xMidYMid meet'
      );
      assert.deepEqual(pageErrors, []);
    } finally {
      await browser.close();
    }
  }
});
