# Wavepoint for iPhone

Wavepoint is a SwiftUI iOS 17 app with bundle ID `ai.mapier.swipe`. A user chooses Spotify or Apple Music, reviews a weighted deck of buried songs, and commits only an explicitly confirmed cleanup batch.

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
- Edge Function: `spotify-token-refresh`
- Edge Function secret required: `SPOTIFY_CLIENT_SECRET`

`Config/Shared.xcconfig` contains only the public Supabase publishable key, project URL, and callback URL. Never put a Spotify client secret, Supabase secret key, or service-role key in the iOS target.

The refresh function is deployed with gateway JWT verification disabled because it validates the bearer token against `/auth/v1/user` inside the handler. This keeps compatibility with current Supabase signing keys while still rejecting callers without a valid Supabase user.

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

Select the configured Apple Development team for `ai.mapier.swipe`, then run on an iPhone or simulator. Spotify OAuth can be exercised on either, but App Remote requires the Spotify iOS app and a physical iPhone. After the Spotify deck loads, Wavepoint may open Spotify automatically with the first cleanup track; every following card autoplays a 15-second segment while the connection remains active.

The provider picker and Apple eligibility UI can be checked in Simulator. Treat Apple Music authorization, subscription status, library loading, playback, playlist creation/editing, and the `OPEN IN MUSIC` destination as physical-device release gates; simulator MusicKit behavior is not authoritative.

## Verification

```bash
xcodebuild test -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild archive -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'generic/platform=iOS' -archivePath /tmp/Wavepoint.xcarchive CODE_SIGNING_ALLOWED=NO
```

Before a release:

1. With an allowlisted Spotify Premium account, test both callback captures, a large paginated library, the automatic first-track Spotify switch, three card transitions without another switch, 15-second stop, pause/resume, swipe and undo, Review stopping playback, Cancel resuming playback, and a deliberately small confirmed removal batch.
2. On a physical iPhone with Apple Music and Sync Library, test permission denial/recovery, subscription and Sync Library blockers, complete library pagination, centered artwork, automatic 15-second playback across three cards, swipe/undo/review, Dumpster creation, a second batch merging without duplicates, `OPEN IN MUSIC`, and the truthful manual **Delete from Library** instructions.
3. Switch providers with and without pending decisions. Confirm the warning appears only when leaving an unconfirmed batch and that Apple Music never exposes Supabase account deletion.
