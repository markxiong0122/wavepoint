# Wavepoint for iPhone

Wavepoint is a SwiftUI iOS 17 app with bundle ID `ai.mapier.swipe`. It signs in through Supabase's Spotify provider, ranks buried Liked Songs, stages keep/remove decisions locally, and commits only a confirmed removal batch.

## External configuration

### Spotify Developer Dashboard

- Bundle ID: `ai.mapier.swipe`
- Supabase OAuth redirect URI: `https://pvlykxebusgsgrtrkrqh.supabase.co/auth/v1/callback`
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

## Generate and run

```bash
cd ios
xcodegen generate
open Wavepoint.xcodeproj
```

Select an Apple Development team for `ai.mapier.swipe`, then run on an iPhone or simulator. OAuth can be exercised on either. This MVP uses a Spotify-provided preview when one exists and otherwise offers Open in Spotify.

## Verification

```bash
xcodebuild test -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild archive -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'generic/platform=iOS' -archivePath /tmp/Wavepoint.xcarchive CODE_SIGNING_ALLOWED=NO
```

Before a release, test with an allowlisted Spotify account: callback capture, a large paginated library, preview available/unavailable states, swipe and undo, review cancel, and a deliberately small confirmed removal batch.
