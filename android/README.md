# Wavepoint for Android

Wavepoint's Android app cleans Spotify Liked Songs with the same weighted,
50-card review flow as iOS. Android is Spotify-only in this release and requires
Spotify Premium because 15-second card autoplay uses Spotify App Remote.

## Local build

Requirements: JDK 17, Android SDK 36, and an API 26+ device.

```bash
./gradlew testDebugUnitTest assembleDebug
```

The debug APK is written to `app/build/outputs/apk/debug/app-debug.apk`.

## Spotify dashboard setup

Wavepoint uses Spotify client ID `6603fd9c06fe40bd823ecacd102c96ed`.
In the Spotify Developer Dashboard, keep these redirect URIs:

- Supabase Web OAuth: `https://pvlykxebusgsgrtrkrqh.supabase.co/auth/v1/callback`
- App Remote: `ai.mapier.swipe://spotify-app-remote-callback`

Add an Android package entry under **Edit settings**:

- Package: `ai.mapier.swipe`
- Development SHA-1: `9D:1E:A4:6B:E1:A0:FC:EA:CD:C6:C2:A0:C5:33:EB:52:00:D5:04:CF`

Before a Play release, generate the release or Play App Signing SHA-1 and add it
as another Android package fingerprint. Never commit a release keystore.

The committed Gradle configuration does not define a release signing key. `bundleRelease`
produces the release bundle for lint/build verification, but it is not ready for Play upload
until an upload-key signing configuration is supplied through local or CI secrets. Keep the
keystore, passwords, and signing properties outside the repository, then register the matching
SHA-1 in Spotify before testing the Play-installed build.

The Supabase Auth redirect allowlist must also contain
`ai.mapier.swipe://login-callback`. Web OAuth returns there through the intent
filter in `AndroidManifest.xml`. App Remote uses Spotify's installed app plus the
registered package/fingerprint; it requires a logged-in Spotify app on a physical
device or Play-enabled emulator.

## Public configuration

The Supabase project URL, Supabase publishable key, Spotify client ID, and callback
URI are public client configuration in `app/build.gradle.kts`. Service-role keys,
Spotify client secrets, and release signing material must never be added to the
app.

Spotify provider credentials are encrypted with AES-GCM behind Android Keystore.
Account deletion calls the existing authenticated `delete-account` Supabase Edge
Function, then clears local provider credentials only after the server confirms
deletion. It does not delete the user's Spotify account or songs.

## Vendored Spotify SDK

Spotify App Remote `0.8.0` is pinned under `spotify-app-remote/`. Verify the
official binary before publishing:

```bash
cd spotify-app-remote
shasum -a 256 -c SHA256SUMS
```
