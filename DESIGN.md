# Design System — Wavepoint

## Product context

- **What this is:** A fast Spotify Liked Songs cleanup app. It surfaces buried tracks one at a time so the user can hear a segment and confidently keep or remove each song.
- **Who it is for:** People with years of accumulated Liked Songs who want a lighter, more intentional library without manual playlist administration.
- **Space:** Music-library utilities and listening companions.
- **Project type:** Mobile-first responsive web app.
- **Primary promise:** Finally delete no-longer-listened-to songs in a fun, fast way.
- **Primary measure:** Confident song decisions per minute.

Daily music recommendations are not part of the first version.

## Aesthetic direction

- **Direction:** Record-sleeve arcade.
- **Decoration:** Intentional. Print-like borders, restrained paper texture, and stamped counters support the interaction without competing with album art.
- **Mood:** Tactile, kinetic, slightly irreverent, and exact. The app should feel more like a two-minute game than a library-management dashboard.
- **Composition:** The active track card is the hero. Everything else stays flat and quiet enough to support a fast binary decision.
- **Reference products:** [Swipefy](https://swipefy.app/) for the category mechanic and [Spotify Dedup](https://spotify-dedup.com/) for utility positioning. Wavepoint differentiates by making visible reduction the reward loop.

## Typography

- **Display:** Bricolage Grotesque, variable width 92–96, weight 700–800. Its compact forms create speed and poster energy without sacrificing legibility.
- **Body:** DM Sans, weight 400–700. It remains legible in compact track metadata and controls.
- **UI labels:** IBM Plex Mono, weight 500–600. Use it for timers, counters, keyboard hints, and short uppercase system labels.
- **Loading:** Google Fonts for the prototype. Production should self-host the exact WOFF2 subsets.

### Type scale

- Display XL: `clamp(4.2rem, 8.8vw, 8.8rem)`, line-height `0.82`
- Display L: `clamp(3.2rem, 7vw, 6.6rem)`, line-height `0.90`
- Track title: `clamp(2rem, 7vw, 2.72rem)`, line-height `0.94`
- Panel title: `1.55rem`, line-height `1`
- Body L: `1.2rem`, line-height `1.55`
- Body: `1rem`, line-height `1.55`
- UI label: `0.62–0.72rem`, line-height `1.35`

Use tight negative tracking only on display type. Body and system labels use normal or slightly positive tracking.

## Color

- **Approach:** Restrained signal palette. Color communicates action and state rather than decorating every surface.
- **Paper:** `#F4F0E7` — primary light background.
- **Raised paper:** `#FFFAF0` — track cards and specimen panels.
- **Ink:** `#151513` — primary type, borders, and hard shadows.
- **Dark surface:** `#1C1B18` — cleanup-stage frame.
- **Mid dark surface:** `#292824` — card stack depth.
- **Muted:** `#A9A298` — quiet borders and secondary information.
- **Muted ink:** `#67635C` on light surfaces.
- **Remove:** `#FF5A3D` — stage removal, removal threshold, and removal count.
- **Keep:** `#D4FF63` — keep action, progress, completion, and primary success.
- **Audio:** `#77A7FF` — playback state, focus, and audio progress.

Color must never be the only state indicator. Pair remove and keep colors with words and symbols.

### Dark mode

Dark mode inverts the page canvas to ink and the text to paper. The active track card remains warm paper so album art and metadata retain the same reading hierarchy. Semantic colors do not change.

## Spacing

- **Base unit:** 4px.
- **Density:** Compact inside the cleanup stage; spacious in the surrounding poster composition.
- **Scale:** 4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 128px.
- **Touch target minimum:** 48px.
- **Card internal padding:** 12px around art, 16–18px around metadata.
- **Section spacing:** 76–140px depending on viewport.

## Shape and depth

- **Control radius:** 6px.
- **Panel radius:** 14px.
- **Hero track-card radius:** 24px desktop, 19px compact mobile.
- **Pill radius:** Reserved for counters and true binary state chips.
- **Borders:** 2px solid ink for major boundaries; 1px soft ink for internal dividers.
- **Active-card shadow:** 7px hard offset shadow.
- **App-frame shadow:** 12px hard remove-colored offset on desktop, 7px on mobile.
- **Supporting content:** Flat. Do not add generic floating card shadows.

Avoid using the same rounded rectangle treatment everywhere. The hierarchy of radii must make the active song feel singular.

## Layout

- **Approach:** Hybrid. A poster-like editorial introduction frames a disciplined single-task app stage.
- **Desktop:** Two-column hero with expressive copy on the left and a 520px cleanup stage on the right.
- **Tablet and mobile:** One column, with the cleanup stage capped at 560px and centered.
- **Content width:** 1320px for primary sections, 1440px for header and footer.
- **Grid:** 48px paper-grid background on the surrounding canvas only.
- **Album art:** Display complete and unobstructed. Never crop, distort, place copy over, or add branding to Spotify artwork.

## Components

### Track card

- Complete square album art at the top.
- Save-age label and recent-rotation signal above the title.
- Track title and artist form the primary reading order.
- Audio control, 15-second progress, and card index sit below metadata.
- Remove and keep hints remain visible near the bottom edge.

### Decision controls

- Remove sits left and uses `× Remove` on the remove color.
- Keep sits right and uses `✓ Keep` on the keep color.
- Undo sits between them as the quiet neutral control.
- Buttons, keyboard shortcuts, and pointer swipes call the same decision action.

### Progress

- Show decisions completed and staged removals at all times.
- Show elapsed time, not a countdown, to avoid anxiety.
- Completion summarizes decisions, removals, elapsed time, and listening time cleared.

### Destructive-state rule

Swipes stage removals. A later production review screen commits the batch to Spotify. Do not permanently delete on the swipe itself.

## Motion

- **Approach:** Intentional and interaction-led.
- **Drag:** 1:1 pointer tracking; rotation capped at 7 degrees.
- **Threshold:** Reveal remove or keep label after about 30% horizontal travel.
- **Decision exit:** 220ms with `cubic-bezier(0.16, 1, 0.3, 1)`.
- **Next-card entry:** 280ms with a small vertical settle.
- **Button micro-interaction:** 120ms translate, no elastic scale.
- **Reduced motion:** Remove rotation and overshoot. Preserve state changes with near-instant opacity changes.

Motion must make the next decision available quickly. It must never become a reward animation the user has to wait through.

## Accessibility

- Provide visible high-contrast focus rings in audio blue.
- Use words and symbols in addition to semantic colors.
- Keep decision targets at least 48px.
- Announce decisions and undo through a polite live region.
- Support left arrow for remove, right arrow for keep, and `Z` for undo.
- Respect `prefers-reduced-motion`.
- Do not depend on hover for essential content.

## Spotify implementation constraints

- Use `added_at` for save age.
- Describe recent evidence as “outside recent rotation”; do not claim an exact last-listened date or play count.
- Use the Web Playback SDK as the primary production audio path. Treat deprecated nullable preview URLs as a fallback only.
- Require an initiating user gesture before expecting continuous segment playback.
- Stage and batch library removals through the current generic library endpoint.
- Preserve artwork and include required Spotify attribution and links in production.

## Logo

- **Selected mark:** Cut Record.
- **Construction:** An ink record is cleanly cut by a directional wedge; a coral label and acid-lime cut line turn deletion into a precise, musical action.
- **Primary lockup:** Ink record, coral center label, paper cutout, and keep-colored cut line.
- **Clear space:** At least one center-label radius around the mark.
- **Do not:** Use Spotify green, a circular sound-wave mark, or the Spotify wordmark as part of Wavepoint identity.

## Decisions log

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-07-09 | Scope v1 to swipe cleanup only | One strong loop is achievable in a day and directly solves the stated pain. |
| 2026-07-09 | Use record-sleeve arcade direction | It makes cleanup playful and fast while keeping album art central. |
| 2026-07-09 | Make reduction the reward | Competing swipe products focus on discovery; Wavepoint should celebrate library progress. |
| 2026-07-09 | Stage removals before committing | Speed needs a safe undo boundary before destructive API calls. |
| 2026-07-09 | Select Cut Record as the product mark | It makes the cleanup promise immediate while retaining a tactile music identity. |
