# Liked Songs Cleanup Design

## Product outcome

Wavepoint gives an iPhone user a fast way to decide whether buried Spotify Liked Songs still belong in their library. The app presents one complete track card at a time, makes listening and deciding reachable with one thumb, stages removals safely, and mutates Spotify only after a review and explicit confirmation.

Success means a user can connect Spotify, load a useful deck from a large library, make keep/remove decisions quickly, undo mistakes, review the staged removals, and finish a confirmed batch without losing unrelated liked songs.

## Approaches considered

### 1. Delete immediately on every left swipe

This is the fastest implementation and gives instant visible progress. It is also too risky: a stray gesture becomes a network mutation, undo requires a second mutation, and partial failures are hard to explain.

### 2. Stage decisions locally, then confirm one batch — selected

Every swipe updates only the current in-memory cleanup session. Undo is instant. The review screen lists only staged removals, and one destructive confirmation calls Spotify in chunks. This matches the approved interaction design while keeping the one-day MVP small.

### 3. Persist every cleanup session in Supabase

This would enable cross-device recovery and analytics, but it adds schema, row-level security, synchronization, and privacy work without improving the first cleanup session. It is explicitly deferred.

## Architecture

The app stays client-first. `SpotifyWebAPIClient` owns authenticated Spotify HTTP calls. `CleanupDeckBuilder` creates a weighted-random deck using evidence Spotify actually exposes: saved age and whether a track appears in recently played history. Older tracks and tracks outside recent rotation receive higher selection odds, while the random shuffle keeps repeat sessions from feeling like a chronological archive. `CleanupSessionModel` owns one observable state machine for loading, swiping, undo, review, batch removal, completion, and recoverable errors.

The root session model supplies the Spotify access token from Keychain after Supabase authentication. No Spotify client secret or Supabase service-role key exists in the app. The first version holds decisions in memory; leaving the session before confirmation discards the staged batch without changing Spotify.

## Data flow

1. Fetch all liked tracks with `GET /v1/me/tracks`, following pagination.
2. Fetch recent history with `GET /v1/me/player/recently-played`.
3. Reduce the selection weight for tracks present in recent history.
4. Apply a seeded weighted shuffle so older saves are more likely, not guaranteed, to appear earlier.
5. Present up to 50 tracks per cleanup session so the task feels finite.
6. Keep and remove gestures append a local decision and reveal the next card.
7. Undo removes the most recent decision and restores its card.
8. Review shows staged removals only.
9. Confirm sends Spotify URIs to `DELETE /v1/me/library` in chunks of at most 40.
10. Completion reports decisions and removals. If a later chunk fails, the app reports the committed count and leaves the remaining tracks staged for retry.

## Track playback

The card always shows artwork, title, artist, save age, and a Spotify link. When Spotify returns a usable preview URL, Wavepoint plays a short segment with `AVPlayer`. Preview URLs are optional, so a missing preview becomes an honest “Preview unavailable” state rather than a broken control. Spotify App Remote remains the physical-device enhancement for exact-track playback; it does not block the cleanup MVP.

## Interaction and accessibility

The Cut Record visual system remains unchanged: ink stage, warm paper card, coral remove, acid-lime keep, audio blue, hard-offset shadows, and compact radii. Drag follows the finger one-to-one, rotates no more than seven degrees, and commits after roughly 30% horizontal travel. Remove and Keep buttons call the same decision functions as gestures. Every action has a word and symbol, 48-point minimum touch targets, VoiceOver labels, and reduced-motion behavior.

## Errors and safety

- A missing or expired Spotify token returns to a reconnect state instead of attempting anonymous requests.
- Rate limits honor `Retry-After` once and then show a retry action.
- Loading failure keeps the user signed in and offers retry.
- Removal is never triggered by a swipe alone.
- The confirm control states the exact removal count.
- Empty libraries and no-ranked-result sessions receive dedicated completion copy.

## Verification

Pure unit tests cover pagination, decoding, deterministic ranking, decision/undo transitions, review count, chunking at 40 URIs, partial failure, and error mapping. Simulator tests cover the observable state machine and build. A physical iPhone checkpoint validates OAuth callback capture, a real Liked Songs fetch, preview/App Remote behavior, and a deliberately small confirmed removal batch.
