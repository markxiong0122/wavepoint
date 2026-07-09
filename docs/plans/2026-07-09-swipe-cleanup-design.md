# Wavepoint Swipe Cleanup Design

## Objective

Wavepoint helps one Spotify user review and remove buried Liked Songs in a fun, fast session. The first version has one job: maximize confident song decisions per minute.

Daily recommendations are explicitly out of scope.

## Product promise

"Finally delete the songs I no longer listen to without turning library cleanup into admin work."

The primary success signal is visible reduction: songs decided, songs staged for removal, minutes cleared, and elapsed time.

## User flow

1. The user starts a 20-song cleanup sprint.
2. A single card shows uncropped album art, track name, artist, save age, and a recent-rotation signal.
3. A mock 15-second segment begins after the initial start interaction.
4. The user swipes left to stage removal or right to keep the song.
5. Kept songs are marked locally as reviewed so they do not immediately resurface.
6. The user can undo the latest choice at any time.
7. The sprint summary shows decisions, removals, listening time cleared, and elapsed time.
8. Staged removals are reviewed before a real API implementation commits them in batches.

## Spotify feasibility constraints

- `GET /me/tracks` supplies saved tracks, metadata, art, duration, and `added_at`.
- Candidate weight should be 60% saved-age percentile, 25% absence from the latest 50 plays, 15% absence from four-week top tracks, plus small random jitter.
- Spotify does not expose exact lifetime per-track play counts or reliable last-played dates. UI copy must say "outside recent rotation," never claim a precise last-listened date.
- `DELETE /me/library` accepts up to 40 Spotify URIs per request. Removal should be staged and committed in batches.
- The Web Playback SDK supports playback and seeking for Premium users, but browser autoplay requires an initiating user gesture. The illustration uses mock audio progress only.
- `preview_url` is deprecated and nullable, so it cannot be the primary production playback path.
- Album art must remain uncropped and unobstructed, with Spotify attribution in the production app.
- Development Mode is suitable for the owner and a small allowlist, not a general consumer launch.

## Visual direction

### Record-sleeve arcade

The interface combines record-store print design with the speed and feedback of an arcade cabinet. It should feel tactile and kinetic, but never noisy enough to slow decisions.

- Display type: Bricolage Grotesque
- Body and UI: DM Sans
- Timers and metrics: IBM Plex Mono
- Paper: `#F4F0E7`
- Ink: `#151513`
- Delete: `#FF5A3D`
- Keep and progress: `#D4FF63`
- Audio: `#77A7FF`
- Muted: `#A9A298`
- Dark surface: `#1C1B18`

### Shape and depth

- Controls: 6px radius
- Supporting panels: 14px radius
- Hero swipe card: 24px radius
- Borders: 2px ink
- Active card: one 7px hard offset shadow
- Supporting UI: flat or a restrained soft shadow
- Touch targets: at least 48px

The system avoids uniformly rounded containers. The swipe card is the only highly rounded hero object.

### Motion

- The card tracks the pointer directly and rotates no more than 7 degrees.
- Decision labels appear at 30% horizontal travel.
- Committed cards leave in 220ms with a sharp ease-out.
- The next card settles in 280ms with a restrained paper-slap overshoot.
- Keyboard, button, and pointer interactions share the same state transitions.
- Reduced-motion mode removes rotation and overshoot.

### Accessibility

- Removal and keep states use words and icons in addition to color.
- Focus states are visible and high contrast.
- Buttons have accessible labels.
- The prototype supports keyboard decisions: left arrow removes, right arrow keeps, and `Z` undoes.
- Motion respects `prefers-reduced-motion`.

## Components

- Working-mark header and sprint timer
- Progress rail with current count
- Swipe stack with album art and track metadata
- Mock audio progress and pause control
- Remove, undo, and keep controls
- Staged-removal count
- Live status announcement
- Sprint-complete result panel
- Design-token and logo-concept strip below the primary mockup

## Logo directions

1. Swipe W: opposing swipe paths create a W with a play-triangle counter.
2. Cut Record: a record with one clean wedge removed.
3. Fast Note: fast-forward geometry whose negative space suggests a music note.

The Swipe W is the recommended working mark because it carries motion, music, and the keep/remove decision without resembling Spotify's identity.

## Prototype boundaries

The deliverable is a self-contained responsive HTML illustration with inline CSS, JavaScript, SVG logo marks, generated album-art illustrations, and mock song data. It makes no network requests and does not authenticate with Spotify.

## Verification

- Open directly in current Chrome, Safari, and Firefox.
- Verify layout at 390px, 768px, and 1440px widths.
- Complete a sprint with pointer, button, and keyboard controls.
- Verify undo restores the prior card and metrics.
- Verify reduced motion and visible focus behavior.
- Confirm there are no external runtime dependencies beyond optional web-font loading.
