# Wavepoint for iPhone

Wavepoint is a SwiftUI iOS 17 app with bundle ID `ai.mapier.swipe`. A user chooses Spotify, Apple Music, or an explicit local demo, reviews a weighted deck of songs, and commits only an explicitly confirmed cleanup batch.

## External configuration

### Spotify Developer Dashboard

- Bundle ID: `ai.mapier.swipe`
- Supabase OAuth redirect URI: `https://pvlykxebusgsgrtrkrqh.supabase.co/auth/v1/callback`
- App Remote redirect URI: `ai.mapier.swipe://spotify-app-remote-callback`
- APIs used: Web API and iOS where enabled
- Development-mode testers must be added under Users Management.

Spotify development mode supports at most five allowlisted users and requires the app owner to have Premium. A broader App Store audience requires Spotify extended quota/partner approval; App Store distribution alone does not remove Spotify's API allowlist.

### Supabase

- Project ref: `pvlykxebusgsgrtrkrqh`
- Project URL: `https://pvlykxebusgsgrtrkrqh.supabase.co`
- Spotify provider: enabled
- Redirect allowlist: `ai.mapier.swipe://login-callback`
- Edge Functions: `spotify-token-refresh` and `delete-account`
- Spotify Edge Function secrets required: `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET`
- Supabase-provided Edge Function environment required: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`

`Config/Shared.xcconfig` contains public client configuration: the Supabase publishable key and URL, OAuth callbacks, Spotify client ID, and optional PostHog token/host. Never put a Spotify client secret, Supabase secret key, or service-role key in the iOS target.

Both functions validate the bearer token against `/auth/v1/user` inside the handler. This keeps compatibility with current Supabase signing keys while still rejecting callers without a valid Supabase user. `spotify-token-refresh` keeps the Spotify client secret server-side; `delete-account` removes the authenticated Supabase user.

### Apple Music

- Enable MusicKit for the registered App ID `ai.mapier.swipe` in Apple Developer.
- The user must grant Media & Apple Music access, have an active Apple Music subscription, and enable Sync Library.
- Apple Music does not provide an API for Wavepoint to delete songs from the user's main library. Confirming a batch creates or updates `Wavepoint Dumpster 🗑️`; the songs remain in the library until the user chooses **Delete from Library** in Music.
- The Apple Music path does not use Supabase and does not upload library data to Wavepoint-controlled servers.

## Generate and run

```bash
cd ios
xcodegen generate
open Wavepoint.xcodeproj
```

Select the configured Apple Development team for `ai.mapier.swipe`, then run on an iPhone or simulator. Spotify OAuth can be exercised on either, but App Remote requires the Spotify iOS app and a physical iPhone. After connecting a provider, Wavepoint starts loading the library behind the 10-, 25-, and 50-song run picker. Spotify fetches its remaining saved-track pages with at most four concurrent requests. Starting the selected run may open Spotify automatically with the first cleanup track; every following card autoplays a 15-second segment while the connection remains active.

**Try a Demo Cleanup** is a release-safe reviewer and first-run path. It uses 50 fictional tracks plus the bundled `wavepoint-demo-preview.m4a`, runs through the same batch picker and cleanup state machine, and has no provider destination or library write. Demo-specific copy remains visible through review and completion; exiting returns to the provider picker.

The provider picker and Apple eligibility UI can be checked in Simulator. Treat Apple Music authorization, subscription status, library loading, playback, playlist creation/editing, and the `OPEN IN MUSIC` destination as physical-device release gates; simulator MusicKit behavior is not authoritative.

### Apple Music Simulator state QA

DEBUG Simulator builds accept `-WavepointAppleMusicDemo <scenario>` as a launch argument. The harness uses deterministic local tracks, makes no MusicKit or Supabase calls for the Apple path, and disables PostHog and Crashlytics. It is excluded from Release and physical-device builds.

Add the two arguments to the Wavepoint scheme or launch an installed debug build with `simctl`. Supported scenarios are:

| Scenario | Expected state |
| --- | --- |
| `eligible` | Cleanup deck, review, Dumpster completion, and another batch |
| `permission-denied` | Open Settings recovery |
| `account-not-ready` | Finish setup in Music recovery |
| `service-unavailable` | Retryable connection failure |
| `subscription-required` | Apple Music subscription blocker |
| `sync-library-required` | Sync Library blocker |

Example:

```bash
xcrun simctl launch booted ai.mapier.swipe -WavepointAppleMusicDemo eligible
```

Do not use this harness as evidence that a real Apple Music account, playback session, or playlist write works.

## Verification

```bash
xcodebuild test -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild archive -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'generic/platform=iOS' -archivePath /tmp/Wavepoint.xcarchive CODE_SIGNING_ALLOWED=NO
```

Before a release:

1. Without signing in, complete the public demo from all three run sizes through swipe, undo, review, completion, another run, and exit. Confirm no music app opens and no provider destination appears.
2. With an allowlisted Spotify Premium account, test both callback captures, visible progress for a large paginated library, all three run sizes, the automatic first-track Spotify switch, three card transitions without another switch, 15-second stop, pause/resume, swipe and undo, Review stopping playback, Cancel resuming playback, and a deliberately small confirmed removal batch.
3. On a physical iPhone with Apple Music and Sync Library, test permission denial/recovery, subscription and Sync Library blockers, complete library pagination, centered artwork, automatic 15-second playback across three cards, swipe/undo/review, Dumpster creation, a second batch appending only new tracks without duplicates, `OPEN IN MUSIC`, and the truthful manual **Delete from Library** instructions.
4. Switch providers with and without pending decisions. Confirm the warning appears only when leaving an unconfirmed batch and that Apple Music never exposes Supabase account deletion.
