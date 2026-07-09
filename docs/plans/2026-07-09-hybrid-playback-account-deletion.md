# Hybrid Playback and Account Deletion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make missing Spotify previews useful through explicit, optional App Remote playback; add compliant in-app account deletion; and produce a verified App Store build.

**Architecture:** Preserve the existing AVPlayer preview path and add a shared Spotify App Remote adapter used only after a user taps a missing-preview card. Keep account deletion server-authoritative in a Supabase Edge Function that derives the target user from the bearer token, then clears the deleted user's local Supabase session and Spotify Keychain credentials. Wire both features through small protocols so behavior can be tested without Spotify, Supabase, or a physical device.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, Spotify iOS SDK 5.0.1, Supabase Swift, Deno Edge Functions, XCTest, XcodeGen.

---

## Task 1: Specify hybrid playback behavior

**Files:**
- Modify: `ios/WavepointTests/TrackPreviewPlayerTests.swift`
- Modify: `ios/Wavepoint/Audio/TrackPreviewPlayer.swift`

1. Add failing tests proving a track with `previewURL` uses AVPlayer without App Remote, a missing preview exposes an explicit Spotify action, remote playback auto-pauses after 15 seconds, and stopping a card cancels the timer and pauses the active source.
2. Run:
   `xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WavepointTests/TrackPreviewPlayerTests`
   Expected: FAIL because the remote playback dependency and source-aware states do not exist.
3. Add the smallest source-aware controller and a `SpotifyRemotePlaying` protocol. Keep existing direct-preview behavior unchanged.
4. Re-run the focused test target and expect PASS.
5. Commit: `feat: add hybrid track playback behavior`.

## Task 2: Integrate Spotify App Remote without mandatory app switching

**Files:**
- Create: `ios/Wavepoint/Audio/SpotifyAppRemoteService.swift`
- Create: `ios/WavepointTests/SpotifyAppRemoteServiceTests.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/TrackCardView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Modify: `ios/Wavepoint/Features/AppRootView.swift`
- Modify: `ios/Wavepoint/App/WavepointApp.swift`
- Modify: `ios/Wavepoint/Auth/SpotifyAuthorizationRequest.swift`
- Modify: `ios/project.yml`
- Modify: `ios/Config/Shared.xcconfig`

1. Add failing adapter tests for: connected playback stays in Wavepoint; disconnected playback first tries a token-backed connection; a connection failure wakes Spotify only after the explicit user tap; callback URLs resume the pending connection; missing installation yields a useful error.
2. Run the focused App Remote tests and confirm the expected compile/test failure.
3. Add Spotify iOS SDK 5.0.1 through XcodeGen, public client ID configuration, `spotify` query scheme, and callback URL `ai.mapier.swipe://spotify-app-remote-callback`.
4. Implement an `@MainActor` App Remote service that owns the SDK connection for the app session. Use the existing provider access token, call `authorizeAndPlayURI` only when a user-requested connection cannot be established, and forward `.onOpenURL` callbacks from the app root.
5. Add `app-remote-control` to Spotify OAuth scopes.
6. Update the card UI: direct previews retain the current control; missing previews show `PLAY 15S IN SPOTIFY` with a one-time app-switch explanation and preserve `OPEN IN SPOTIFY` as fallback.
7. Run focused tests, regenerate the Xcode project with `xcodegen generate --spec ios/project.yml`, and re-run the full iOS suite.
8. Register the new App Remote callback in Spotify Developer Dashboard using the approved browser access if it is not already present.
9. Commit: `feat: play missing previews with Spotify`.

## Task 3: Delete only the authenticated Supabase account

**Files:**
- Create: `supabase/functions/delete-account/index.ts`
- Create: `supabase/functions/delete-account/index.test.ts`
- Modify: `supabase/config.toml`

1. Write failing Deno tests proving missing/invalid bearer tokens return 401, the admin deletion path always uses the user ID returned by `/auth/v1/user`, request bodies cannot choose another user, and upstream deletion errors are surfaced without reporting success.
2. Run:
   `deno test --allow-env supabase/functions/delete-account/index.test.ts`
   Expected: FAIL because the handler does not exist.
3. Implement an injectable handler. Authenticate with the incoming bearer token and publishable key, then delete exactly that user through the server-only service-role admin endpoint. Support `DELETE` and CORS preflight only.
4. Re-run the Edge Function tests and expect PASS.
5. Deploy with `verify_jwt=false`; the function performs its own bearer validation because the existing Supabase gateway configuration rejects the project's current provider JWT format.
6. Exercise unauthorized and authenticated non-destructive validation paths. Do not delete the developer account during QA.
7. Commit: `feat: add authenticated account deletion endpoint`.

## Task 4: Add double-confirmed in-app account deletion

**Files:**
- Create: `ios/Wavepoint/Auth/AccountDeletionService.swift`
- Create: `ios/WavepointTests/AccountDeletionServiceTests.swift`
- Modify: `ios/Wavepoint/Auth/SpotifyAuthenticating.swift`
- Modify: `ios/Wavepoint/Auth/SupabaseSpotifyAuthenticator.swift`
- Modify: `ios/Wavepoint/Auth/AppSessionModel.swift`
- Modify: `ios/WavepointTests/AppSessionModelTests.swift`
- Create: `ios/Wavepoint/Features/Account/AccountSheetView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Modify: `ios/Wavepoint/Features/AppRootView.swift`

1. Add failing service/model tests proving the bearer token is sent to the delete endpoint, successful deletion clears the local Supabase session and Spotify Keychain credentials, failure preserves the signed-in state and displays an actionable error, and sign-out behavior remains unchanged.
2. Run the two focused test classes and confirm the expected failures.
3. Implement the deletion client and local-session clearing method, then add a deleting state to `AppSessionModel`.
4. Replace the header's direct sign-out action with an Account sheet. Include Sign Out and Delete Account; require a destructive button followed by a final destructive confirmation explaining what is and is not removed.
5. Re-run focused tests and the complete iOS suite.
6. Commit: `feat: add in-app account deletion`.

## Task 5: Compliance, signed release, and App Store Connect

**Files:**
- Modify: `PRIVACY.md`
- Modify: `docs/privacy.html`
- Modify: `APP_STORE.md`
- Modify: `ios/project.yml`
- Modify: `release/README.md`
- Modify: `release/SHA256SUMS`
- Create: `release/Wavepoint-0.1.0-2.ipa`

1. Update the privacy disclosure to accurately describe Supabase email/provider identity storage, local Spotify tokens, account deletion, and no server storage of the user's music library. Record the App Store privacy-label answers: email address and user ID linked to the user for app functionality; no tracking.
2. Update review notes to explain optional App Remote playback and that Spotify may open once after an explicit tap.
3. Set build number 2, regenerate the Xcode project, and run all iOS and Deno tests.
4. Exercise sign-in, direct/missing-preview presentation, keep, remove staging, undo, review, account sheet, and both deletion confirmation stages in Simulator without confirming a real account deletion. Verify App Remote on a physical device if one is connected; otherwise document that device-only check precisely.
5. Archive and export a signed App Store IPA. Verify its signature, bundle identifier, version/build, icon, privacy manifest, and checksum.
6. Use Chrome to create the App Store Connect app record, populate version metadata/privacy fields, and upload build 2. Stop only at Apple-controlled processing/review or a credential/contract screen requiring Mark's personal attestation.
7. Run the simplify and verification-before-completion reviews, commit release metadata, push the branch, and monitor CI/review feedback.

