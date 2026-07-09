# Swipe Cleanup HTML Illustration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a polished, self-contained HTML illustration of Wavepoint's swipe-only Spotify cleanup sprint.

**Architecture:** One `wavepoint-swipe-prototype.html` file contains semantic HTML, design tokens, responsive CSS, mock track data, and a small interaction state machine. A Playwright test exercises the file directly through `file://`, so the artifact needs no server, package manifest, build step, or network API.

**Tech Stack:** HTML5, CSS custom properties, inline SVG, vanilla JavaScript, Node.js built-in test runner, bundled Playwright.

---

### Task 1: Define the browser behavior contract

**Files:**
- Create: `tests/swipe-prototype.test.cjs`
- Test: `tests/swipe-prototype.test.cjs`

**Step 1: Write the failing behavior test**

Create a Node test that launches bundled Chromium, opens the local HTML file, and asserts the user-visible contract:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');

const prototypeUrl = pathToFileURL(
  path.resolve(__dirname, '..', 'wavepoint-swipe-prototype.html')
).href;

test('supports remove, undo, keep, keyboard, and completion', async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await page.goto(prototypeUrl);

  const firstTitle = await page.locator('[data-track-title]').textContent();
  await page.getByRole('button', { name: /stage .* removal/i }).click();
  assert.equal(await page.locator('[data-staged-count]').textContent(), '1');
  assert.notEqual(await page.locator('[data-track-title]').textContent(), firstTitle);

  await page.getByRole('button', { name: /undo/i }).click();
  assert.equal(await page.locator('[data-track-title]').textContent(), firstTitle);
  assert.equal(await page.locator('[data-staged-count]').textContent(), '0');

  await page.keyboard.press('ArrowRight');
  assert.notEqual(await page.locator('[data-track-title]').textContent(), firstTitle);

  await browser.close();
});
```

Add tests for pointer swiping, final results, responsive overflow, accessible status updates, and uncropped artwork.

**Step 2: Run the test to verify it fails**

Run:

```bash
NODE_PATH=/Users/mark/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules \
  /Users/mark/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  --test tests/swipe-prototype.test.cjs
```

Expected: FAIL because `wavepoint-swipe-prototype.html` does not exist.

### Task 2: Build the visual shell

**Files:**
- Create: `wavepoint-swipe-prototype.html`
- Test: `tests/swipe-prototype.test.cjs`

**Step 1: Add semantic structure and design tokens**

Create the document with:

- A working-mark header and sprint timer
- A progress rail and staged-removal counter
- A swipe-card stack
- Uncropped generated album artwork
- Track metadata and recent-rotation explanation
- Mock audio progress
- Remove, undo, and keep controls
- A completion panel
- A lower design-system and logo-concept section

Use the approved token variables:

```css
:root {
  --paper: #f4f0e7;
  --ink: #151513;
  --remove: #ff5a3d;
  --keep: #d4ff63;
  --audio: #77a7ff;
  --muted: #a9a298;
  --surface-dark: #1c1b18;
  --radius-control: 6px;
  --radius-panel: 14px;
  --radius-card: 24px;
  --border: 2px solid var(--ink);
  --shadow-card: 7px 7px 0 var(--ink);
}
```

**Step 2: Implement responsive composition**

Use a single-column cleanup stage below 900px and a two-column poster composition above 900px. Keep the decision controls visible without horizontal scrolling at 390px.

**Step 3: Preserve accessibility in the shell**

Include a skip link, one `h1`, visible focus styles, 48px controls, `aria-live="polite"`, labeled buttons, text labels in addition to semantic colors, and a reduced-motion media query.

### Task 3: Implement the swipe state machine

**Files:**
- Modify: `wavepoint-swipe-prototype.html`
- Test: `tests/swipe-prototype.test.cjs`

**Step 1: Add mock track data and state**

Keep data local and small:

```js
const tracks = [
  {
    title: 'Golden Hour Drive',
    artist: 'Mara Vale',
    saved: 'Saved 8 years ago',
    signal: 'Outside your recent rotation',
    durationSeconds: 246,
    art: 'sunset'
  }
];

const state = {
  index: 0,
  decisions: [],
  removedSeconds: 0,
  startedAt: Date.now()
};
```

**Step 2: Implement one decision function**

Route button, keyboard, and drag input through `decide('remove' | 'keep')`. The function records the decision, updates metrics, animates the outgoing card, renders the next track, and announces the state through the live region.

**Step 3: Implement pointer swiping**

Track pointer movement, cap rotation at seven degrees, reveal decision labels after 30% travel, and commit after a 110px threshold. Otherwise spring the card back to origin.

**Step 4: Implement undo**

Restore the last track, decision count, staged count, and cleared duration. Disable undo when no decision exists.

**Step 5: Implement mock audio and completion**

Animate a 15-second mock segment while a card is active. Pause on demand. At the end, replace the deck with a result panel showing decisions, removals, minutes cleared, and elapsed time. Allow a restart.

**Step 6: Run browser tests**

Run the Task 1 command.

Expected: all tests PASS with no page errors.

**Step 7: Commit the working prototype**

```bash
git add wavepoint-swipe-prototype.html tests/swipe-prototype.test.cjs
git commit -m "feat: add interactive swipe cleanup prototype"
```

### Task 4: Record the approved design system

**Files:**
- Create: `DESIGN.md`
- Create: `CLAUDE.md`

**Step 1: Write `DESIGN.md`**

Convert the approved system into the project source of truth: product context, record-sleeve arcade direction, typography, palette, spacing, shape hierarchy, layout, motion, accessibility, Spotify-content constraints, and decisions log.

**Step 2: Write `CLAUDE.md`**

Add the project rule:

```markdown
## Design System

Always read DESIGN.md before making visual or UI decisions. All font choices, colors, spacing, motion, and aesthetic direction are defined there. Do not deviate without explicit user approval. In QA, flag code that does not match DESIGN.md.
```

**Step 3: Verify documentation**

Run:

```bash
git diff --check
```

Expected: no output.

**Step 4: Commit the design source of truth**

```bash
git add DESIGN.md CLAUDE.md
git commit -m "docs: add Wavepoint design system"
```

### Task 5: Perform visual and interaction QA

**Files:**
- Modify if required: `wavepoint-swipe-prototype.html`
- Modify if required: `tests/swipe-prototype.test.cjs`

**Step 1: Capture reference screenshots**

Use bundled Playwright to capture the prototype at 390×844 and 1440×1000 into `/tmp`.

**Step 2: Inspect both screenshots**

Check hierarchy, clipping, responsive behavior, art rendering, contrast, control placement, and whether the primary interaction reads within three seconds.

**Step 3: Run the full verification set**

Run:

```bash
git diff --check
NODE_PATH=/Users/mark/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules \
  /Users/mark/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  --test tests/swipe-prototype.test.cjs
```

Expected: formatting check is silent and all browser tests pass.

**Step 4: Open the artifact**

```bash
open wavepoint-swipe-prototype.html
```

Expected: the prototype opens in the user's default browser.

**Step 5: Commit any QA corrections**

Stage only the corrected files and create a conventional fix or style commit. Skip this step if QA requires no changes.
