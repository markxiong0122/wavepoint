# Design System — Wavepoint

## Product context

- **What this is:** A native music-library cleanup app. It surfaces buried tracks one at a time so the user can hear a segment and confidently keep or stage each song for cleanup.
- **Who it is for:** People with years of accumulated Spotify Liked Songs or Apple Music library tracks who want a lighter, more intentional library without manual playlist administration.
- **Space:** Music-library utilities and listening companions.
- **Project type:** Native iPhone and Android apps. iPhone supports Spotify and Apple Music; Android supports Spotify in the current release.
- **Primary promise:** Finally clean up no-longer-listened-to songs in a fun, fast way.
- **Primary measure:** Confident song decisions per minute.

Daily music recommendations are not part of the first version.

## Aesthetic direction

- **Direction:** Record-sleeve arcade.
- **Decoration:** Intentional. Print-like borders, restrained paper texture, and stamped counters support the interaction without competing with album art.
- **Mood:** Tactile, kinetic, slightly irreverent, and exact. The app should feel more like a two-minute game than a library-management dashboard.
- **Composition:** The active track card is the hero. Everything else stays flat and quiet enough to support a fast binary decision.
- **Reference products:** [Swipefy](https://swipefy.app/) for the category mechanic and [Spotify Dedup](https://spotify-dedup.com/) for utility positioning. Wavepoint differentiates by making visible reduction the reward loop.

## Typography

- **Display:** Native rounded system type at heavy and black weights remains the fast, compact primary display face.
- **Editorial accent:** Averia Serif Libre Bold is bundled locally and reserved for the cleanup-run picker and similarly rare editorial moments. Keep it to roughly 10–15% of visible type; never use it for track titles, controls, counters, or body copy.
- **Body:** Native system type at medium through bold weights for compact track metadata and controls.
- **UI labels:** Native monospaced system type at semibold through black weights for timers, counters, and short uppercase system labels.
- **Prototype note:** The historical HTML prototype uses Bricolage Grotesque, DM Sans, and IBM Plex Mono. Production native clients otherwise use system fonts.

### Prototype type scale

These responsive values apply to the historical HTML prototype. Native production screens use the same hierarchy with platform system sizes rather than CSS units.

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

### Dark stage

The native apps ship with a fixed ink canvas and paper track card so album art and metadata retain the same reading hierarchy. Semantic colors do not change. A separate adaptive light theme is not part of the current release.

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
- **Phone:** One portrait column with the cleanup card sized from the available height so metadata and playback controls never slide under the fixed action row.
- **Large prototype canvas:** The historical HTML concept uses a two-column poster composition. It is a visual reference, not the native production layout.
- **Album art:** Center and fill the artwork frame without distortion or blank bars. A small edge crop is allowed when the adaptive card is not square. Never place copy over or add branding to provider artwork.

## Components

### Cleanup-run picker

- Offer **Needle Drop · 10**, **Side A · 25**, and **Crate Dig · 50** before the deck. Side A is the initial recommendation and the last selection is remembered locally.
- Keep the numeric size dominant even when the mode name carries personality.
- Start the provider library scan behind the picker and show truthful progress without uploading library size to analytics.
- Use Averia Serif Libre Bold for the picker headline and mode names only. Counts, status, and the start control remain monospaced system type.

### Track card

- Centered album artwork fills the adaptive frame at the top.
- Save-age label and card index above the title.
- Track title and artist form the primary reading order.
- The 15-second audio control and provider link sit below metadata.
- Remove, undo, and keep controls remain visible in the fixed action row below the card.

### Decision controls

- Remove sits left and uses `× Remove` on the remove color.
- Keep sits right and uses `✓ Keep` on the keep color.
- Undo sits between them as the quiet neutral control.
- Buttons and touch swipes call the same decision action.

### Progress

- Show decisions completed and staged removals at all times.
- Do not add a countdown that makes the cleanup session feel timed or anxious.
- Completion states the confirmed provider result and the correct next action.

### Destructive-state rule

Swipes stage cleanup choices. The existing review screen either commits Spotify removals or appends Apple Music choices to the Dumpster playlist. Do not change a provider library on the swipe itself.

## Motion

- **Approach:** Intentional and interaction-led.
- **Drag:** 1:1 pointer tracking; rotation capped at 7 degrees.
- **Threshold:** Reveal remove or keep label after about 30% horizontal travel.
- **Decision exit:** 180–220ms with a fast ease-out curve.
- **Next-card entry:** 280ms with a small vertical settle.
- **Button micro-interaction:** 120ms translate, no elastic scale.
- **Reduced motion:** Remove rotation and overshoot. Preserve state changes with near-instant opacity changes.

Motion must make the next decision available quickly. It must never become a reward animation the user has to wait through.

## Accessibility

- Provide visible high-contrast focus rings in audio blue.
- Use words and symbols in addition to semantic colors.
- Keep decision targets at least 48px.
- Give decisions, playback, undo, and recovery controls explicit accessibility labels and stable identifiers.
- Respect the native Reduce Motion accessibility setting.
- Do not depend on pointer hover or color for essential content.

## Provider implementation constraints

### Spotify

- Use `added_at` for save age.
- Do not imply recent-listening evidence or claim an exact last-listened date or play count. Production decks use saved age only.
- Play a 15-second segment when Spotify supplies a preview URL. Treat deprecated nullable preview URLs as optional and always provide Open in Spotify.
- Require an initiating user gesture before expecting continuous segment playback.
- Stage and batch library removals through the current generic library endpoint.
- Preserve artwork and include required Spotify attribution and links in production.

### Apple Music

- Require Media & Apple Music permission, an active subscription, and Sync Library before loading a cleanup deck.
- Treat MusicKit authorization, subscription, playback, library pagination, and playlist writes as physical-device release gates.
- Never claim the Dumpster update deleted a song. Tell the user to choose **Delete from Library** inside Music.
- Append only newly staged tracks to an existing Dumpster playlist; do not rebuild it from historical song identifiers.

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
