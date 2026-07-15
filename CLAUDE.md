# Wavepoint Project Guidance

## Product scope

The first release is a review-first music-library swipe-cleanup experience. iPhone supports Spotify and Apple Music; Android supports Spotify. Daily recommendation playlists are out of scope.

Optimize for one measurable outcome: confident song decisions per minute. Keep implementation small and complete across the cleanup flow.

## Design system

Always read `DESIGN.md` before making visual or UI decisions. All font choices, colors, spacing, motion, accessibility, and aesthetic direction are defined there. Do not deviate without explicit user approval. In QA, flag code that does not match `DESIGN.md`.

## Spotify language

Spotify does not expose exact lifetime play counts or a reliable per-track last-listened date. The production app does not request recent-listening access; rank cleanup decks from saved age without implying listening history or inventing precision.

Swipes stage removals. A separate review step commits the batch. Do not make the swipe itself an irreversible API call.

## Apple Music language

MusicKit cannot delete songs from the user's main Apple Music library. Confirmed Apple Music choices append to `Wavepoint Dumpster 🗑️`; the user must finish with **Delete from Library** inside Music. Never describe **Remove from Playlist** or a successful Dumpster update as library deletion.

Apple Music library data stays on device and does not use Supabase. Authorization, subscription, Sync Library, playback, and Dumpster writes require physical-device verification; Simulator scenarios are UI/state QA only.

## Platform references

Use `README.md` for the product and documentation index, `ARCHITECTURE.md` for provider/data boundaries, and the platform READMEs for setup and release gates. Historical files under `docs/plans/` explain past decisions but are not current setup instructions.
