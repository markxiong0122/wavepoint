# Apple Music Simulator Readiness Design

## Goal

Make the Apple Music cleanup path ready for subscribed-device testing while enabling reliable UI and state QA in Simulator without claiming that Simulator verifies MusicKit.

## Boundaries

- Real authorization, subscription status, library requests, playback, and playlist writes remain physical-device release gates.
- Simulator behavior is enabled only in DEBUG builds when the `-WavepointAppleMusicDemo` launch argument is present.
- Release and TestFlight builds always use the real MusicKit dependencies.
- The demo never writes Supabase, Apple Music, PostHog, or Firebase data.

## Simulator architecture

The demo reuses `AppRootView`, `MusicProviderSessionModel`, `CleanupSessionModel`, `CleanupHomeView`, playback coordination, review, and completion. Only the external provider boundaries are replaced:

- an Apple Music authorizer returns the selected eligibility scenario;
- a cleanup library service returns deterministic Apple Music tracks and a Dumpster result;
- an Apple Music player client simulates successful playback state transitions.

The launch argument accepts an optional scenario value:

- `eligible` (default)
- `permission-denied`
- `account-not-ready`
- `service-unavailable`
- `subscription-required`
- `sync-library-required`

This gives QA access to the real app state machine and layout without adding a second mock UI or a visible production switch.

## Real MusicKit hardening

The Dumpster must append only newly staged songs to its existing playlist. Rebuilding the complete playlist requires historical songs to remain resolvable after users delete them from their library, which breaks subsequent batches. Apple documents `MusicLibrary.add(_:to:)` as the API for adding an item to the end of an existing playlist.

Starting another cleanup batch must clear prior decisions before loading. A failed new load must not expose an already committed review batch. Playback coordination must also reset its automatic/manual preference for the new deck.

## Error handling

The previously implemented Apple Music connection taxonomy remains the entry boundary: permission, account setup, subscription, Sync Library, and service configuration failures remain distinct. The demo exercises these public states directly; it does not add demo-specific screens.

## Verification

- Regression tests prove incremental Dumpster appends do not require historical deleted songs.
- Session tests prove a failed new load cannot restore a prior review batch.
- Playback tests prove a new deck retries automatic playback after a prior manual fallback.
- Demo configuration tests prove the launch argument is DEBUG/Simulator gated and maps every supported scenario.
- Full iOS tests and unsigned archive must pass.
- Android and Edge Function gates must remain green.
- The next TestFlight build receives a physical-device matrix covering subscription, Sync Library, permission, account setup, autoplay, and Dumpster creation/update.
