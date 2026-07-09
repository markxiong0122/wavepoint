# Liked Songs Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the complete iPhone cleanup loop from authenticated Spotify token through ranked track cards, swipe decisions, safe review, and confirmed batch removal.

**Architecture:** A small async Spotify client handles typed Web API requests. Pure ranking and decision types remain independent of SwiftUI and network code; one `@MainActor @Observable` cleanup model composes them for the UI. Swipes stage removals in memory, and only review confirmation mutates Spotify.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation `URLSession`, AVFoundation, XCTest, Spotify Web API, iOS 17+

---

### Task 1: Spotify track models and deterministic deck ranking

**Files:**
- Create: `ios/Wavepoint/Spotify/SpotifyTrack.swift`
- Create: `ios/Wavepoint/Cleanup/CleanupDeckBuilder.swift`
- Test: `ios/WavepointTests/CleanupDeckBuilderTests.swift`

**Step 1: Write failing ranking tests**

Create tracks with controlled `addedAt` dates and recent-track IDs. Assert that older and outside-rotation tracks receive higher weights, the same seed reproduces an ordering, different seeds vary it, and results are capped at 50.

**Step 2: Run the test and verify RED**

Run:

```bash
xcodegen generate --spec ios/project.yml
xcodebuild build-for-testing -quiet -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: compile failure because `SpotifyTrack` and `CleanupDeckBuilder` do not exist.

**Step 3: Implement the minimum pure models and ranking**

Define `SpotifyTrack` with ID, URI, title, artist names, artwork URL, optional preview URL, Spotify URL, duration, and `addedAt`. Use a seeded weighted shuffle where saved age raises the weight and recent presence reduces it. Return at most 50.

**Step 4: Run the focused test and verify GREEN**

Run the focused test with `-only-testing:WavepointTests/CleanupDeckBuilderTests`.

**Step 5: Commit**

```bash
git add ios
git commit -m "feat: rank buried Spotify tracks"
```

### Task 2: Typed Spotify Web API client

**Files:**
- Create: `ios/Wavepoint/Spotify/SpotifyWebAPIClient.swift`
- Test: `ios/WavepointTests/SpotifyWebAPIClientTests.swift`

**Step 1: Write failing URL protocol tests**

Stub paginated `/v1/me/tracks` responses and `/v1/me/player/recently-played`. Assert authorization headers, page following, model decoding, and a 401 mapping to `authorizationExpired`.

**Step 2: Run and verify RED**

Expected: compile failure because the API client does not exist.

**Step 3: Implement the read client**

Inject `URLSession` and access-token closure. Decode Spotify's snake-case envelopes with ISO-8601 dates. Follow the response `next` URL until nil. Fetch recent history with a limit of 50.

**Step 4: Add removal tests and implementation**

Assert an empty URI list performs no request, 41 URIs produce requests of 40 and 1, and the body is `{ "uris": [...] }`. Implement `DELETE https://api.spotify.com/v1/me/library` with JSON content type.

**Step 5: Run focused tests and commit**

```bash
git add ios
git commit -m "feat: add Spotify library API client"
```

### Task 3: Cleanup session state machine

**Files:**
- Create: `ios/Wavepoint/Cleanup/CleanupSessionModel.swift`
- Test: `ios/WavepointTests/CleanupSessionModelTests.swift`

**Step 1: Write failing state tests**

Cover loading a ranked deck, keeping, staging removal, undo, entering review, cancelling review, confirmation, empty library, and retryable load failure with a fake library service.

**Step 2: Run and verify RED**

Expected: compile failure because the cleanup model does not exist.

**Step 3: Implement the observable model**

Use one state enum: idle, loading, deciding, reviewing, committing, complete, and failed. Keep ordered decisions so undo restores the exact top card. Expose derived progress and staged-removal arrays.

**Step 4: Verify GREEN and commit**

```bash
git add ios
git commit -m "feat: model safe cleanup sessions"
```

### Task 4: Swipe deck and review UI

**Files:**
- Create: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Create: `ios/Wavepoint/Features/Cleanup/TrackCardView.swift`
- Create: `ios/Wavepoint/Features/Cleanup/RemovalReviewView.swift`
- Create: `ios/Wavepoint/Features/Cleanup/CleanupCompleteView.swift`
- Modify: `ios/Wavepoint/Features/AppRootView.swift`
- Modify: `ios/Wavepoint/App/WavepointApp.swift`
- Test: `ios/WavepointTests/CleanupScreenTests.swift`

**Step 1: Write failing screen-mapping tests**

Assert stable accessibility identifiers for loading, deck, review, commit progress, completion, and retry error states.

**Step 2: Implement the Cut Record cleanup stage**

Build a full-height ink stage, progress header, stacked warm-paper cards, AsyncImage artwork, drag gesture capped at seven degrees, 30% threshold, Remove/Undo/Keep controls, and exact review count. Respect Reduce Motion and keep actions accessible without swiping.

**Step 3: Wire live dependencies**

Pass a token-loading closure from Keychain into the API client and create the cleanup model only after the auth state is signed in.

**Step 4: Build, run focused tests, and commit**

```bash
git add ios
git commit -m "feat: build liked-song swipe cleanup"
```

### Task 5: Optional preview playback

**Files:**
- Create: `ios/Wavepoint/Audio/TrackPreviewPlayer.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/TrackCardView.swift`
- Test: `ios/WavepointTests/TrackPreviewPlayerTests.swift`

**Step 1: Write failing playback-state tests**

Assert unavailable URL, loading, playing, paused, failed, and automatic 15-second stop using an injected playback engine/clock.

**Step 2: Implement AVPlayer playback**

Play only from a user gesture, stop when the top card changes, expose plain-language unavailable/failure states, and keep an Open in Spotify link.

**Step 3: Verify and commit**

```bash
git add ios
git commit -m "feat: play available track previews"
```

### Task 6: Release assets, privacy, and full verification

**Files:**
- Create: `ios/Wavepoint/Resources/Assets.xcassets/AppIcon.appiconset/*`
- Create: `ios/Wavepoint/Resources/PrivacyInfo.xcprivacy`
- Create: `ios/README.md`
- Create: `PRIVACY.md`
- Modify: `ios/project.yml`
- Modify: `DESIGN.md`

**Step 1: Generate the Cut Record app icon set**

Render the approved vector mark at 1024 square with no transparency and create the asset catalog metadata.

**Step 2: Add privacy and release metadata**

Declare the app's accessed APIs and data handling accurately, add Spotify URL query schemes if App Remote is included, document external callback/key setup, and prohibit secrets in the bundle.

**Step 3: Run full verification**

Run:

```bash
git diff --check
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild archive -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'generic/platform=iOS' -archivePath /tmp/Wavepoint.xcarchive CODE_SIGNING_ALLOWED=NO
```

Expected: all unit tests pass, simulator build succeeds, and an unsigned generic iOS archive is produced.

**Step 4: Physical-device release checkpoint**

On an allowlisted Spotify account, validate OAuth callback, library load, one available preview or Spotify fallback, undo, and a two-track confirmed removal batch. Restore those tracks manually if the test account needs them.

**Step 5: Commit**

```bash
git add ios DESIGN.md PRIVACY.md
git commit -m "chore: prepare Wavepoint for iPhone release"
```
