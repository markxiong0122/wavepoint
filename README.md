# Wavepoint

Wavepoint turns an overloaded music library into a fast, review-first cleanup session. The iPhone app lets the user choose a 10-, 25-, or 50-song run, surfaces a weighted deck of older saved songs, and plays a short segment for each decision. Nothing changes until the user reviews and confirms the batch.

## Current product

| Platform | Providers | Cleanup result |
| --- | --- | --- |
| iPhone, iOS 17+ | Spotify, Apple Music, and local demo | Spotify removes confirmed tracks from Liked Songs. Apple Music adds confirmed tracks to `Wavepoint Dumpster 🗑️` for manual **Delete from Library** in Music. The explicit demo uses fictional local tracks and changes nothing. |
| Android, API 26+ | Spotify | Removes confirmed tracks from Liked Songs. |

Spotify cleanup requires Premium because automatic card playback uses Spotify App Remote. While the Spotify integration remains in Development Mode, testers must also be allowlisted in the Spotify developer dashboard. Apple Music requires Media & Apple Music permission, an active subscription, and Sync Library.

The iPhone provider picker also offers **Try a Demo Cleanup**. It exercises the run picker, automatic local sample, swipe/undo, review, and completion without an account or provider request/write. This is the App Review path while Spotify remains limited to approved testers.

Daily recommendation playlists are not part of this release.

## Safety and privacy

- Swipes only stage decisions. The provider library changes after review and explicit confirmation.
- Spotify OAuth runs through Supabase. Provider credentials stay in iOS Keychain or Android Keystore-backed encrypted storage.
- Apple Music library access stays on the device and does not use the Wavepoint Supabase backend.
- Track names, identifiers, artists, artwork, library size, and individual decisions are excluded from product analytics and crash reports.
- Apple Music cannot be deleted through MusicKit. Wavepoint tells the user to finish deletion inside Music instead of claiming the Dumpster update deleted anything.

See [PRIVACY.md](PRIVACY.md) for the full policy and [docs/analytics-contract.md](docs/analytics-contract.md) for the telemetry allowlist.

## Run locally

### iPhone

Requirements: Xcode 26 or newer, XcodeGen, and an Apple Development team for `ai.mapier.swipe`.

```bash
cd ios
xcodegen generate
open Wavepoint.xcodeproj
```

Spotify App Remote and real MusicKit account behavior require a physical iPhone. The provider picker, cleanup flow, and deterministic Apple Music recovery states can be exercised in Simulator; see [ios/README.md](ios/README.md).

### Android

Requirements: JDK 17, Android SDK 36, and an API 26+ device or emulator.

```bash
cd android
./gradlew testDebugUnitTest assembleDebug
```

See [android/README.md](android/README.md) for Spotify dashboard fingerprints, release signing, and the vendored App Remote SDK checksum.

## Verify

The CI-equivalent local checks are:

```bash
cd ios
xcodegen generate
xcodebuild test -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild archive -project Wavepoint.xcodeproj -scheme Wavepoint -destination 'generic/platform=iOS' -archivePath /tmp/Wavepoint.xcarchive CODE_SIGNING_ALLOWED=NO
```

```bash
cd android
./gradlew testDebugUnitTest lintDebug bundleRelease lintRelease
```

```bash
deno fmt --check supabase/functions
deno test supabase/functions/spotify-token-refresh/index_test.ts supabase/functions/delete-account/index_test.ts
```

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md): provider boundaries, shared state, playback, commits, and observability.
- [DESIGN.md](DESIGN.md): the record-sleeve arcade design system and interaction rules.
- [APP_STORE.md](APP_STORE.md): App Store copy, review steps, privacy answers, and screenshots.
- [PRIVACY.md](PRIVACY.md): source privacy policy; hosted copies live under `docs/`.
- [ios/README.md](ios/README.md) and [android/README.md](android/README.md): platform setup and physical-device release gates.
- [docs/observability-setup.md](docs/observability-setup.md), [docs/release-checklist.md](docs/release-checklist.md), and [docs/release-operations.md](docs/release-operations.md): production key handoff, rollout gates, and monitoring.
- [release/README.md](release/README.md): signed iOS artifacts and build-specific release notes.
- [docs/plans](docs/plans): historical design and implementation plans. These explain past decisions but are not the current setup reference.

## Release status

TestFlight build 8 (`0.1.0`) was uploaded and accepted by App Store Connect. Public release is still gated on the unchecked items in [docs/release-checklist.md](docs/release-checklist.md), including physical Apple Music verification and observability configuration.
