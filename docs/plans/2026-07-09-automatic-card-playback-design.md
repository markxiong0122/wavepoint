# Automatic Card Playback Design

## Goal

Remove playback taps from the cleanup loop. After Supabase finishes Spotify login and the cleanup deck is ready, Wavepoint automatically opens Spotify with the first cleanup track. Spotify returns to Wavepoint with that track already playing, and each following card starts its own 15-second segment automatically.

## Product decision

Supabase authentication stays unchanged. Wavepoint does not add a second setup button and does not resume an unrelated previous Spotify track. The automatic Spotify app switch happens only after the first cleanup track is known, so the sound always matches the card the user is about to review.

The first switch may feel surprising, but the loading screen explains it with `STARTING AUTOPLAY…`. After the App Remote connection is established, the keep/remove loop stays inside Wavepoint.

## Experience

1. The user taps `CONTINUE WITH SPOTIFY` and completes the existing Supabase OAuth flow.
2. Wavepoint loads and ranks the cleanup deck.
3. Wavepoint shows `STARTING AUTOPLAY…` and asks Spotify App Remote to play the first track. Spotify opens automatically if the remote is not already connected.
4. Spotify returns to Wavepoint. The deck appears with the first track already playing.
5. Swiping or tapping Keep/Remove pauses the outgoing track, replaces the card, and starts the next track automatically.
6. The card audio control remains available as pause/resume. Each automatic segment stops after 15 seconds.
7. Review, completion, sign-out, and leaving the deck stop active playback.

If automatic setup fails, Wavepoint shows the existing actionable playback error with `TRY AGAIN` and `CONTINUE WITHOUT AUTOPLAY`. Manual mode preserves direct previews, the Spotify play button, and `OPEN IN SPOTIFY`.

## Architecture

`CleanupHomeView` owns one shared `TrackPreviewPlayer` for the cleanup session. `TrackCardView` receives that player instead of constructing a new one. This keeps the first App Remote task and 15-second timer alive when the setup screen transitions into the deck, and it guarantees that one player stops before another track starts.

A small cleanup playback state distinguishes:

- `starting`: the deck is loaded and first-track App Remote authorization is pending;
- `automatic`: the first track started successfully and card changes should autoplay;
- `manual`: setup was skipped or failed and card controls remain explicit.

The first automatic start forces the Spotify App Remote source even when Spotify exposes a direct preview. This wakes Spotify with the correct cleanup track and establishes the shared connection. While automatic mode remains active, every card uses App Remote for consistent exact-track playback. Direct `AVPlayer` previews remain the fallback for manual mode.

Playback transitions run from SwiftUI lifecycle tasks keyed by the current track ID, never from `body`. A transition stops the current source, prepares the new URI, and starts playback. Cancellation or leaving the deck stops the player and prevents a late callback from starting a stale card.

`SpotifyAppRemoteService` continues to own callback coordination, connection timeout, and the single app-session remote connection. It may try the existing token-backed connection first; only a failed connection invokes Spotify authorization and the external app switch.

## Error handling

- Spotify missing: offer manual mode and `OPEN IN SPOTIFY`.
- Authorization denied or callback missing: return to a retryable setup state with the localized error.
- Connection lost between cards: try one normal reconnect. If Spotify authorization is required again, the app may switch to Spotify once; failure falls back to manual mode instead of repeatedly switching.
- Track change during an in-flight start: cancel the stale task and stop any playback it initiated.
- Direct preview or remote pause failure: keep the deck usable and show the existing compact card error.

## Testing

Unit tests cover:

- first-track setup waits for App Remote authorization and starts only once;
- the deck appears without restarting the already-playing first track;
- advancing a card stops the outgoing track before starting the next URI;
- undo performs the same ordered transition;
- every automatic segment stops after 15 seconds;
- setup errors expose retry and manual fallback;
- leaving the deck cancels pending work and stops playback.

The physical-device checkpoint verifies the automatic Spotify switch, callback return, first-track continuity, at least three automatic card transitions, pause/resume, and no additional Spotify switch while the remote connection stays healthy.

## Non-goals

- Replacing Supabase authentication.
- Removing the existing account-deletion flow.
- Background playback after leaving cleanup.
- A persistent autoplay preference or settings screen in this version.
- Changing cleanup ranking, swipe decisions, or batch removal behavior.
