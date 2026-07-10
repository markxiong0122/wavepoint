# Cross-Provider Expansion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship one Wavepoint iOS app with Spotify Premium cleanup plus a fully wired Apple Music Dumpster flow, and a native Android Spotify cleanup app with matching product behavior.

**Architecture:** Keep ranking and cleanup session behavior provider-neutral, then adapt Spotify and MusicKit behind small protocols. The iOS root owns provider selection and constructs the matching auth, library, playback, and commit adapters; Android repeats the proven domain/state-machine behavior in Kotlin rather than migrating the existing SwiftUI application.

**Tech Stack:** Swift 6, SwiftUI, Observation, MusicKit, Spotify iOS SDK, Supabase Swift, XCTest, XcodeGen; Kotlin, Jetpack Compose, coroutines/StateFlow, Supabase Kotlin Auth, OkHttp/kotlinx.serialization, Android Keystore, Spotify Android App Remote 0.8.0, JUnit, Compose UI tests.

---

## Working rules

- Follow `@superpowers:test-driven-development`: write one behavioral test, run it red, add the minimum implementation, run it green.
- Keep each numbered task in its own small commit and push it before starting the next task.
- Do not change Spotify's shipped behavior during provider-neutral refactors.
- Never describe Apple Music songs as deleted; the Apple commit result is a playlist update.
- Treat simulator MusicKit work as exploratory. A real-device MusicKit pass remains a release gate.
- After simulator/emulator phases, shut down devices and stop Gradle daemons to protect RAM.
- Use official primary documentation for SDK/version decisions:
  - `https://developer.apple.com/documentation/musickit`
  - `https://developer.spotify.com/documentation/web-api`
  - `https://developer.spotify.com/documentation/android`
  - `https://supabase.com/docs/reference/kotlin`

## Task 1: Gate Spotify sessions before cleanup

**Files:**
- Modify: `ios/Wavepoint/Auth/SupabaseSpotifyAuthenticator.swift`
- Modify: `ios/Wavepoint/Auth/AppSessionModel.swift`
- Modify: `ios/Wavepoint/App/WavepointApp.swift`
- Modify: `ios/Wavepoint/Spotify/SpotifyWebAPIClient.swift`
- Modify: `ios/Wavepoint/Features/AppRootView.swift`
- Test: `ios/WavepointTests/SpotifyAuthorizationRequestTests.swift`
- Test: `ios/WavepointTests/SpotifyWebAPIClientTests.swift`
- Test: `ios/WavepointTests/AppSessionModelTests.swift`
- Test: `ios/WavepointTests/AppRootScreenTests.swift`

**Step 1: Write failing Web API and scope tests**

Require `user-read-private`; decode `product` into:

```swift
enum SpotifyAccountEligibility: Equatable, Sendable {
  case premium
  case free
  case unverifiable
}
```

Cover `premium`, `free`, `open`, missing/unknown `product`, `401`, and `403`.

**Step 2: Run the focused tests and verify red**

Run:

```bash
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' \
  -only-testing:WavepointTests/SpotifyAuthorizationRequestTests \
  -only-testing:WavepointTests/SpotifyWebAPIClientTests
```

Expected: FAIL because eligibility and the new scope do not exist.

**Step 3: Add minimal eligibility implementation**

Add `SpotifyAccountEligibilityChecking`, `fetchAccountEligibility()`, and typed errors for forbidden/missing scope versus transient failure. Keep `SpotifyLibraryServing` behavior unchanged.

**Step 4: Write failing session-state tests**

Cover sign-in and restore for Premium, Free/Open, unknown product, missing scope, and a non-allowlisted `403`. Assert that Free credentials are cleared and transient/unknown states do not enter cleanup.

**Step 5: Run session tests and verify red**

Run:

```bash
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' \
  -only-testing:WavepointTests/AppSessionModelTests \
  -only-testing:WavepointTests/AppRootScreenTests
```

Expected: FAIL on the missing blocker states.

**Step 6: Implement session gates and explicit blocker UI**

Add typed states for Premium required, reconnect required, and eligibility unavailable. The login screen says `Spotify Premium required`; blockers offer retry and reconnect rather than reaching App Remote timeout.

**Step 7: Run focused and full iOS tests**

Run the focused command, then:

```bash
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1'
```

Expected: all tests PASS.

**Step 8: Commit and push**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "feat(ios): gate Spotify cleanup by subscription"
git push origin codex/swipe-design-html
```

## Task 2: Make the cleanup domain provider-neutral

**Files:**
- Create: `ios/Wavepoint/Cleanup/LibraryTrack.swift`
- Create: `ios/Wavepoint/Cleanup/CleanupLibraryServing.swift`
- Modify: `ios/Wavepoint/Spotify/SpotifyWebAPIClient.swift`
- Delete: `ios/Wavepoint/Spotify/SpotifyTrack.swift`
- Modify: `ios/Wavepoint/Cleanup/CleanupDeckBuilder.swift`
- Modify: `ios/Wavepoint/Cleanup/CleanupSessionModel.swift`
- Modify: `ios/Wavepoint/Cleanup/CleanupPlaybackCoordinator.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/TrackCardView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/RemovalReviewView.swift`
- Modify: all cleanup and Spotify mapping tests under `ios/WavepointTests`

**Step 1: Add failing provider-neutral model tests**

Define `MusicProvider`, `LibraryTrack`, `CleanupCommitResult`, and a service protocol whose commit method accepts staged provider IDs. Assert Spotify mapping retains URI, preview, artwork, destination URL, and dates.

**Step 2: Run cleanup tests and verify red**

```bash
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' \
  -only-testing:WavepointTests/CleanupDeckBuilderTests \
  -only-testing:WavepointTests/CleanupSessionModelTests \
  -only-testing:WavepointTests/CleanupPlaybackCoordinatorTests
```

Expected: FAIL because provider-neutral types do not exist.

**Step 3: Perform the mechanical type migration**

Use one domain model:

```swift
struct LibraryTrack: Identifiable, Equatable, Sendable {
  let id: String
  let provider: MusicProvider
  let playbackID: String
  let title: String
  let artistNames: [String]
  let artworkURL: URL?
  let previewURL: URL?
  let destinationURL: URL?
  let duration: Duration
  let addedAt: Date?
}
```

Avoid provider conditionals inside ranking.

**Step 4: Adapt Spotify and restore green**

Make `SpotifyWebAPIClient` conform to the new protocol and return `.spotify` tracks. Preserve current chunked `DELETE /me/library` behavior.

**Step 5: Run all iOS tests**

Expected: all tests PASS with no UI behavior change.

**Step 6: Commit and push**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "refactor(ios): make cleanup domain provider neutral"
git push origin codex/swipe-design-html
```

## Task 3: Make cleanup presentation provider-aware

**Files:**
- Create: `ios/Wavepoint/Cleanup/CleanupProviderPresentation.swift`
- Modify: `ios/Wavepoint/Cleanup/CleanupSessionModel.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/RemovalReviewView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupCompleteView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/TrackCardView.swift`
- Test: `ios/WavepointTests/CleanupSessionModelTests.swift`
- Test: `ios/WavepointTests/CleanupScreenTests.swift`

**Step 1: Write failing copy/result tests**

Assert Spotify uses `REMOVE` and automatic-removal summaries; Apple uses `TOSS`, `SEND {N} TO THE DUMPSTER`, `DUMPSTER READY`, `OPEN IN MUSIC`, and the manual `Delete from Library` warning.

**Step 2: Run tests and verify red**

Expected: FAIL because all presentation is Spotify-specific.

**Step 3: Add immutable presentation values**

Keep copy out of service implementations. `CleanupProviderPresentation` derives labels and trust copy from `MusicProvider`; `CleanupSummary` carries a typed `CleanupCommitResult`.

**Step 4: Add partial-commit reconciliation to session state**

For Spotify, retain only uncommitted staged tracks on a partial result. For Apple, report only songs confirmed present in the Dumpster.

**Step 5: Run focused and full tests**

Expected: all PASS.

**Step 6: Commit and push**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "feat(ios): add provider-aware cleanup copy"
git push origin codex/swipe-design-html
```

## Task 4: Add Apple Music authorization and eligibility

**Files:**
- Create: `ios/Wavepoint/AppleMusic/AppleMusicAuthorizing.swift`
- Create: `ios/Wavepoint/AppleMusic/MusicKitAuthorizationService.swift`
- Create: `ios/Wavepoint/Auth/MusicProviderSessionModel.swift`
- Modify: `ios/Wavepoint/Auth/AppSessionModel.swift`
- Modify: `ios/Wavepoint/Features/AppRootView.swift`
- Test: `ios/WavepointTests/AppleMusicAuthorizationTests.swift`
- Test: `ios/WavepointTests/MusicProviderSessionModelTests.swift`
- Test: `ios/WavepointTests/AppRootScreenTests.swift`

**Step 1: Write failing authorization-state tests**

Cover not determined, authorized, denied, restricted, no catalog playback, and Sync Library disabled. Use local enums in the protocol boundary so tests do not depend on live MusicKit.

**Step 2: Verify red**

Run only the three new/modified test classes. Expected: compile/test failure for missing types.

**Step 3: Implement the MusicKit facade**

Map `MusicAuthorization.request()` and `MusicSubscription.current` into:

```swift
enum AppleMusicEligibility: Equatable, Sendable {
  case eligible
  case permissionDenied
  case restricted
  case subscriptionRequired
  case syncLibraryRequired
}
```

**Step 4: Implement provider-session coordination**

Persist only the selected provider in `UserDefaults`. Apple does not create a Supabase account. Switching providers clears local in-flight cleanup state and stops playback.

**Step 5: Run tests**

Expected: all focused and full iOS tests PASS.

**Step 6: Commit and push**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "feat(ios): authorize Apple Music sessions"
git push origin codex/swipe-design-html
```

## Task 5: Load and rank Apple Music library songs

**Files:**
- Create: `ios/Wavepoint/AppleMusic/AppleMusicLibraryService.swift`
- Create: `ios/Wavepoint/AppleMusic/MusicKitLibraryClient.swift`
- Test: `ios/WavepointTests/AppleMusicLibraryServiceTests.swift`
- Modify: `ios/WavepointTests/CleanupDeckBuilderTests.swift`

**Step 1: Write failing page/mapping tests**

Use fake pages to cover complete pagination, artwork URL generation, artist/title/duration mapping, missing `libraryAddedDate`, recent-ID evidence, and unavailable songs. Assert the deck builder receives the full library before selecting 50.

**Step 2: Verify red**

Expected: FAIL because Apple library adapters do not exist.

**Step 3: Implement the protocol-backed MusicKit client**

Use `MusicLibraryRequest<Song>` pages and a recent-song request. Do not introduce Apple Music developer tokens or server storage.

**Step 4: Implement Apple service mapping**

Return `LibraryTrack(provider: .appleMusic, ...)`; fall back to a deterministic neutral weight when dates are unavailable.

**Step 5: Run focused/full tests and commit**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "feat(ios): load Apple Music cleanup candidates"
git push origin codex/swipe-design-html
```

## Task 6: Add in-app Apple Music segment playback

**Files:**
- Create: `ios/Wavepoint/Audio/CleanupTrackPlaying.swift`
- Create: `ios/Wavepoint/AppleMusic/AppleMusicTrackPlayer.swift`
- Modify: `ios/Wavepoint/Audio/TrackPreviewPlayer.swift`
- Modify: `ios/Wavepoint/Cleanup/CleanupPlaybackCoordinator.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Test: `ios/WavepointTests/AppleMusicTrackPlayerTests.swift`
- Modify: `ios/WavepointTests/CleanupPlaybackCoordinatorTests.swift`

**Step 1: Write failing playback lifecycle tests**

Assert prepare/play, best-effort seek, cancellation on card change, pause after the targeted 15 seconds, stale-task suppression, and unavailable-song errors.

**Step 2: Verify red**

Expected: FAIL because playback is Spotify-shaped.

**Step 3: Add the provider-neutral player boundary**

Adapt existing Spotify playback without changing behavior. Implement Apple playback using a small facade over `ApplicationMusicPlayer` and an injectable clock/sleeper for deterministic tests.

**Step 4: Run focused/full tests and commit**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "feat(ios): play Apple Music cleanup segments"
git push origin codex/swipe-design-html
```

## Task 7: Create and reconcile the Dumpster playlist

**Files:**
- Create: `ios/Wavepoint/AppleMusic/AppleMusicDumpsterService.swift`
- Create: `ios/Wavepoint/AppleMusic/MusicKitPlaylistClient.swift`
- Create: `ios/Wavepoint/AppleMusic/DumpsterPlaylistStore.swift`
- Modify: `ios/Wavepoint/AppleMusic/AppleMusicLibraryService.swift`
- Test: `ios/WavepointTests/AppleMusicDumpsterServiceTests.swift`
- Modify: `ios/WavepointTests/CleanupSessionModelTests.swift`

**Step 1: Write failing Dumpster tests**

Cover first creation, stored-playlist update, deduplication, deleted/unedited stored playlist recovery, empty commit, ambiguous write followed by re-fetch, and truthful counts/destination URL.

**Step 2: Verify red**

Expected: FAIL because no Dumpster commit service exists.

**Step 3: Implement local playlist identity storage**

Persist only the app-created playlist ID. Do not search/edit arbitrary user playlists with the same name.

**Step 4: Implement create/edit/reconcile behavior**

Create `Wavepoint Dumpster 🗑️`; merge stable song IDs; on ambiguous failure re-fetch and retry only missing IDs; recreate only when the stored app-created playlist cannot be resolved or edited.

**Step 5: Run tests and commit**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "feat(ios): add Apple Music Dumpster commits"
git push origin codex/swipe-design-html
```

## Task 8: Wire the iOS provider picker and provider switching end to end

**Files:**
- Modify: `ios/Wavepoint/App/WavepointApp.swift`
- Modify: `ios/Wavepoint/Features/AppRootView.swift`
- Modify: `ios/Wavepoint/Features/Authentication/SpotifyLoginView.swift`
- Create: `ios/Wavepoint/Features/Authentication/MusicProviderPickerView.swift`
- Modify: `ios/Wavepoint/Features/Account/AccountSheetView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Test: `ios/WavepointTests/AppRootScreenTests.swift`
- Create: `ios/WavepointTests/MusicProviderPickerTests.swift`

**Step 1: Write failing root-routing tests**

Cover no provider, Spotify authorizing/gated/signed in, Apple authorizing/gated/ready, provider change, pending-decision warning, and account deletion visibility only for Spotify/Supabase accounts.

**Step 2: Verify red**

Expected: FAIL because root construction is Spotify-only.

**Step 3: Construct provider dependency bundles**

`WavepointApp` builds both provider adapters once. The selected provider chooses the matching cleanup service/player; switching cancels the old player and resets the deck.

**Step 4: Build the two-action entry and Account controls**

Keep the existing Cut Record hierarchy. Add equal `CONTINUE WITH SPOTIFY` and `CONTINUE WITH APPLE MUSIC` actions with eligibility disclosures and accessibility identifiers. Add `CHANGE MUSIC SERVICE` to Account.

**Step 5: Run full tests and commit**

```bash
git add ios/Wavepoint ios/WavepointTests
git commit -m "feat(ios): wire Spotify and Apple Music providers"
git push origin codex/swipe-design-html
```

## Task 9: Configure MusicKit, privacy copy, and release metadata

**Files:**
- Modify: `ios/project.yml`
- Modify: `ios/Wavepoint/Resources/Info.plist` through XcodeGen properties
- Modify: `ios/Wavepoint/Resources/PrivacyInfo.xcprivacy` only if API declarations require it
- Modify: `ios/README.md`
- Modify: `release/README.md`
- Generated: `ios/Wavepoint.xcodeproj/project.pbxproj`

**Step 1: Add a configuration test/assertion**

Check generated build settings contain `NSAppleMusicUsageDescription`, iPhone-only support, bundle `ai.mapier.swipe`, and build number incremented from 4.

**Step 2: Regenerate the project**

```bash
cd ios && xcodegen generate
```

Expected: project generation succeeds and Spotify package settings remain intact.

**Step 3: Enable MusicKit capability**

Use the App ID's MusicKit service in Apple Developer. Do not invent a MusicKit entitlement key if current Xcode manages the service solely through the registered App ID.

**Step 4: Update disclosure/review notes**

Document Spotify Premium and five-user beta constraints, Apple Music/Sync Library requirements, no Apple data upload to Wavepoint-controlled servers, Dumpster truth copy, and real-device test steps.

**Step 5: Build and test**

```bash
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1'
xcodebuild build -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

Expected: tests PASS and generic iOS build succeeds.

**Step 6: Commit and push**

```bash
git add ios release/README.md
git commit -m "build(ios): configure Apple Music release"
git push origin codex/swipe-design-html
```

## Task 10: Exercise iOS and publish the next TestFlight build

**Files:**
- No source changes unless runtime testing reveals a reproduced defect
- Output: `build/Wavepoint.xcarchive`
- Output: `build/export/`

**Step 1: Boot only the iOS 26.1 simulator**

```bash
xcrun simctl boot 'iPhone 17 Pro'
open -a Simulator
```

**Step 2: Run Apple exploratory checks**

Verify provider picker, permission/subscription/Sync Library states, library/deck rendering, centered artwork, card transitions, playback behavior if supported, Dumpster review truth copy, and open-in-Music. Record simulator limitations; do not waive the physical-device gate.

**Step 3: Run final automated verification**

Run full iOS tests, `git diff --check`, and `git status --short`.

**Step 4: Archive and validate**

```bash
xcodebuild archive -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'generic/platform=iOS' \
  -archivePath build/Wavepoint.xcarchive
xcodebuild -exportArchive -archivePath build/Wavepoint.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist -exportPath build/export
```

Expected: archive/export succeeds with the incremented build number.

**Step 5: Upload to App Store Connect**

Use the configured upload path from `release/README.md`; confirm App Store Connect accepts and processes the build.

**Step 6: Shut down simulator and clean transient processes**

```bash
xcrun simctl shutdown all
```

Do not delete archives or derived data that are needed to prove the upload.

## Task 11: Scaffold native Android and port the deterministic core

**Files:**
- Create: `android/settings.gradle.kts`
- Create: `android/build.gradle.kts`
- Create: `android/gradle.properties`
- Create: `android/gradle/libs.versions.toml`
- Create: `android/app/build.gradle.kts`
- Create: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/java/ai/mapier/swipe/MainActivity.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/cleanup/LibraryTrack.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/cleanup/CleanupDeckBuilder.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/cleanup/CleanupSession.kt`
- Create: `android/app/src/test/java/ai/mapier/swipe/cleanup/CleanupDeckBuilderTest.kt`
- Create: `android/app/src/test/java/ai/mapier/swipe/cleanup/CleanupSessionTest.kt`

**Step 1: Confirm installed SDK/JDK without installing duplicates**

```bash
java -version
/Users/mark/Library/Android/sdk/platform-tools/adb version
/Users/mark/Library/Android/sdk/emulator/emulator -list-avds
```

Use installed tooling and a project Gradle wrapper. Record compile/target SDKs actually available.

**Step 2: Create the minimum Compose project**

Package/application ID is `ai.mapier.swipe`; min SDK follows current Supabase Kotlin support (26 unless official docs say otherwise). Add unit-test and Compose-test dependencies only.

**Step 3: Write failing deck/session tests**

Port Swift test fixtures for old-song weighting, recent suppression, deterministic seeded selection, 50-card cap, keep/toss/undo/review, and staged commit state.

**Step 4: Verify red, implement minimal core, verify green**

```bash
cd android && ./gradlew testDebugUnitTest
```

Expected first run: FAIL; after implementation: PASS.

**Step 5: Commit and push**

```bash
git add android
git commit -m "feat(android): scaffold cleanup core"
git push origin codex/swipe-design-html
```

## Task 12: Add Android Supabase OAuth and secure Spotify credentials

**Files:**
- Create: `android/app/src/main/java/ai/mapier/swipe/auth/SupabaseSpotifyAuthenticator.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/auth/SpotifyTokenStore.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/auth/SpotifyCredentialProvider.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/auth/AppSession.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Test: matching files under `android/app/src/test/java/ai/mapier/swipe/auth/`

**Step 1: Write failing auth/token tests**

Cover OAuth scope composition, deep-link session import, `providerToken`/`providerRefreshToken` capture, Keystore-backed encrypted storage abstraction, refresh through `spotify-token-refresh`, forced refresh on 401, and credential clearing.

**Step 2: Verify red**

```bash
cd android && ./gradlew testDebugUnitTest --tests 'ai.mapier.swipe.auth.*'
```

**Step 3: Implement Supabase Kotlin Auth with PKCE**

Use a Custom Tab and a dedicated Wavepoint callback intent filter. Supabase session refresh does not replace Spotify provider refresh.

**Step 4: Implement encrypted storage**

Generate/wrap the encryption key with Android Keystore and encrypt the serialized provider credentials before storing them in app-private preferences/files. Keep crypto behind a fakeable interface.

**Step 5: Run all unit tests and commit**

```bash
git add android
git commit -m "feat(android): add secure Spotify sign in"
git push origin codex/swipe-design-html
```

## Task 13: Add Android Spotify Web API and Premium gating

**Files:**
- Create: `android/app/src/main/java/ai/mapier/swipe/spotify/SpotifyWebApiClient.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/spotify/SpotifyModels.kt`
- Modify: `android/app/src/main/java/ai/mapier/swipe/auth/AppSession.kt`
- Test: `android/app/src/test/java/ai/mapier/swipe/spotify/SpotifyWebApiClientTest.kt`
- Test: `android/app/src/test/java/ai/mapier/swipe/auth/AppSessionTest.kt`

**Step 1: Write failing HTTP/state tests**

Cover complete saved-track pagination, recent IDs, `product` Premium/Free/Open/missing/unknown, `403` tester allowlist copy, 401 refresh/retry, 429 retry, URI-based removal chunks, and partial removal counts.

**Step 2: Verify red, implement minimal client, verify green**

Use injected OkHttp transport/clock. Never treat missing `product` as Free.

**Step 3: Run `testDebugUnitTest` and commit**

```bash
git add android
git commit -m "feat(android): add Spotify library cleanup API"
git push origin codex/swipe-design-html
```

## Task 14: Vendor and wrap Spotify Android App Remote

**Files:**
- Create: `android/spotify-app-remote/spotify-app-remote-release-0.8.0.aar`
- Create: `android/spotify-app-remote/SHA256SUMS`
- Create: `android/spotify-app-remote/LICENSES.md`
- Modify: `android/settings.gradle.kts`
- Modify: `android/app/build.gradle.kts`
- Create: `android/app/src/main/java/ai/mapier/swipe/audio/SpotifyAppRemotePlayer.kt`
- Test: `android/app/src/test/java/ai/mapier/swipe/audio/SpotifyAppRemotePlayerTest.kt`

**Step 1: Fetch only the official pinned release asset**

Use Spotify's GitHub `v0.8.0-appremote_v2.1.0-auth` release, compute SHA-256, and record source/license. Do not accept an arbitrary binary from another host.

**Step 2: Write failing wrapper tests**

Cover connect, app missing, authorization required, targeted play/seek/pause, card-change cancellation, stale timer suppression, and disconnect on lifecycle stop.

**Step 3: Implement the fakeable wrapper**

Register a dedicated App Remote callback. If the Web OAuth already granted `app-remote-control`, connect without unnecessary auth UI; otherwise allow App Remote's authorization view.

**Step 4: Run unit tests/assemble and commit**

```bash
cd android && ./gradlew testDebugUnitTest assembleDebug && cd ..
git add android
git commit -m "feat(android): add Spotify App Remote playback"
git push origin codex/swipe-design-html
```

## Task 15: Build the matching Compose cleanup experience

**Files:**
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/theme/WavepointTheme.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/WavepointApp.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/LoginScreen.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/PremiumBlockerScreen.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/CleanupDeckScreen.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/TrackCard.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/RemovalReviewScreen.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/CleanupCompleteScreen.kt`
- Create: `android/app/src/androidTest/java/ai/mapier/swipe/ui/WavepointFlowTest.kt`

**Step 1: Write failing Compose semantics tests**

Cover Premium disclosure, progress, artwork crop, swipe/remove/keep, undo, review count, confirm boundary, blocker copy, playback/app-missing errors, and completion. Use stable test tags aligned with iOS accessibility identifiers.

**Step 2: Verify red**

Run on one installed emulator only:

```bash
cd android && ./gradlew connectedDebugAndroidTest
```

**Step 3: Implement theme and screens**

Match Wavepoint tokens and layout hierarchy: dark surface, paper card, coral remove, acid-lime keep, audio blue, rounded display text, monospace labels, compact radii, hard offset shadow. Use Compose `ContentScale.Crop` so artwork cannot letterbox.

**Step 4: Wire state and lifecycle**

One activity collects `StateFlow`; card changes drive playback; review is explicit; rotation/process recreation restores only safe auth/provider state, not unconfirmed destructive decisions.

**Step 5: Run unit/UI/lint/assemble and commit**

```bash
cd android
./gradlew testDebugUnitTest connectedDebugAndroidTest lintDebug assembleDebug && cd ..
git add android
git commit -m "feat(android): build Spotify cleanup flow"
git push origin codex/swipe-design-html
```

## Task 16: Complete Android account/settings and external callback setup

**Files:**
- Create: `android/app/src/main/java/ai/mapier/swipe/account/AccountDeletionService.kt`
- Create: `android/app/src/main/java/ai/mapier/swipe/ui/AccountSheet.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/README.md`
- Test: `android/app/src/test/java/ai/mapier/swipe/account/AccountDeletionServiceTest.kt`

**Step 1: Write failing account tests**

Cover authenticated Edge Function deletion, local cleanup after server success, retained session after server failure, sign out, Spotify deep link, and App Remote callback routing.

**Step 2: Implement and verify**

Use existing `delete-account` Edge Function. Add setup instructions for Supabase redirect allowlist and Spotify package/fingerprint/callback.

**Step 3: Generate and report debug SHA-1**

```bash
cd android && ./gradlew signingReport
```

Add the exact debug package/fingerprint to the external-setup checklist; never commit private release keys.

**Step 4: Run full checks and commit**

```bash
git add android
git commit -m "feat(android): complete account and callback setup"
git push origin codex/swipe-design-html
```

## Task 17: Final Android emulator pass, cleanup, and objective audit

**Files:**
- Modify only files required by reproduced defects
- Output: `android/app/build/outputs/apk/debug/app-debug.apk`

**Step 1: Boot one Play-enabled emulator**

Use the smallest installed compatible AVD. Install the debug APK and exercise provider login callback, Premium/allowlist blocker, library loading, card decisions, review, and removal. App Remote requires an installed/logged-in Spotify app; record a physical-device checkpoint if that cannot be satisfied.

**Step 2: Run authoritative Android checks**

```bash
cd android
./gradlew testDebugUnitTest connectedDebugAndroidTest lintDebug assembleDebug
```

Expected: all PASS and debug APK exists.

**Step 3: Run repository-wide hygiene checks**

```bash
git diff --check
git status --short --branch
```

Check for secrets, untracked AAR provenance files, generated signing keys, stale TODOs, and unrelated changes.

**Step 4: Stop heavy processes**

```bash
/Users/mark/Library/Android/sdk/platform-tools/adb emu kill || true
cd android && ./gradlew --stop
xcrun simctl shutdown all
```

Confirm no emulator/simulator/Gradle daemon remains consuming substantial RAM.

**Step 5: Run final simplification and structural audit**

Use `@simplify` on newly modified code. The configured environment has no separate `elegance` skill, so perform the equivalent structural audit manually: remove duplication introduced in this work, confirm provider boundaries are real seams rather than speculative abstractions, and rerun all affected tests.

**Step 6: Commit any verified cleanup separately**

```bash
git add <only-cleanup-files>
git commit -m "refactor: simplify cross-provider cleanup"
git push origin codex/swipe-design-html
```

Skip this commit if the audit produces no changes.

**Step 7: Audit the full objective before completion**

Completion requires evidence for:

- iOS Spotify Free/Open accounts are blocked before App Remote timeout.
- iOS Apple Music authorization, library mapping, playback adapter, Dumpster creation/update, review truth copy, and provider switching are implemented and automated tests pass.
- The next iOS build is accepted by App Store Connect; real-device MusicKit validation is explicitly pending until a device is available.
- Android native Spotify auth, Premium gate, deck, playback wrapper, review/removal, account deletion, tests, lint, and APK assembly are implemented.
- External constraints are reported exactly: Spotify five-user allowlist/quota, MusicKit App ID/device gate, Android package/fingerprints/callbacks.
- Branch commits are pushed and the worktree contains no accidental artifacts.
