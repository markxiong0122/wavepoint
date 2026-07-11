# Apple Music Simulator Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Harden repeat Apple Music cleanup batches, exercise the real UI/state flow through a DEBUG Simulator harness, and publish a TestFlight build for subscribed-device verification.

**Architecture:** Keep production composition on real MusicKit. A launch-argument-gated DEBUG/Simulator factory injects fake provider boundaries into the existing session, cleanup, playback, review, and completion views. Change Dumpster updates from full playlist replacement to incremental append so deleted historical songs are never required.

**Tech Stack:** Swift 6, SwiftUI, Observation, MusicKit, XCTest, XcodeGen, App Store Connect/TestFlight.

---

### Task 1: Append only new Dumpster songs

**Files:**
- Modify: `ios/Wavepoint/AppleMusic/AppleMusicDumpsterService.swift`
- Modify: `ios/Wavepoint/AppleMusic/MusicKitPlaylistClient.swift`
- Test: `ios/WavepointTests/AppleMusicDumpsterServiceTests.swift`

**Step 1: Write the failing test**

Change the fake client event from full replacement to an append operation and assert an existing playlist containing a deleted historical ID only receives the newly staged IDs:

```swift
XCTAssertEqual(client.events, [
  .fetch("dumpster"),
  .append("dumpster", ["new"]),
])
```

**Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'platform=iOS Simulator,id=631E1745-F250-43BE-A651-55636F04F3F5' \
  -only-testing:WavepointTests/AppleMusicDumpsterServiceTests
```

Expected: compile/assertion failure because the protocol still exposes full replacement.

**Step 3: Implement incremental append**

Replace `updatePlaylist(id:name:songIDs:)` with `appendSongs(ids:to:)`. In the system client, resolve only the new IDs and call Apple’s `MusicLibrary.add(_:to:)` once per song, carrying forward the returned playlist. Keep fetch-and-reconcile behavior for ambiguous writes.

**Step 4: Run the focused tests and verify GREEN**

Expected: every Dumpster test passes, including replacement and ambiguous-write recovery.

**Step 5: Commit**

```bash
git commit -m "fix(ios): append new Apple Music dumpster songs"
```

### Task 2: Reset new cleanup batches safely

**Files:**
- Modify: `ios/Wavepoint/Cleanup/CleanupSessionModel.swift`
- Modify: `ios/Wavepoint/Cleanup/CleanupPlaybackCoordinator.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Test: `ios/WavepointTests/CleanupSessionModelTests.swift`
- Test: `ios/WavepointTests/CleanupPlaybackCoordinatorTests.swift`

**Step 1: Write failing session and playback tests**

Add a session test that completes a batch, makes the next load fail, and asserts `stagedRemovals` and decisions are empty. Add a playback test that enters explicit manual mode, calls `resetForNewDeck()`, presents another track, and asserts remote automatic playback is attempted.

**Step 2: Run focused tests and verify RED**

Expected: the prior batch remains staged and manual preference survives.

**Step 3: Implement reset boundaries**

Clear deck, decisions, committed IDs, and counters before the async library fetch begins. Add `resetForNewDeck()` to the playback coordinator to stop playback and reset track ID, deck-started, manual preference, generation, and state. Route the completion screen’s Start Again action through a helper that resets playback before calling `model.load()`.

**Step 4: Run focused tests and verify GREEN**

**Step 5: Commit**

```bash
git commit -m "fix(ios): reset cleanup state between batches"
```

### Task 3: Add the DEBUG Simulator Apple Music harness

**Files:**
- Create: `ios/Wavepoint/App/AppleMusicSimulatorDemo.swift`
- Modify: `ios/Wavepoint/App/WavepointApp.swift`
- Create: `ios/WavepointTests/AppleMusicSimulatorDemoTests.swift`
- Modify: `ios/WavepointTests/ProjectConfigurationTests.swift`

**Step 1: Write failing scenario parser tests**

Assert `-WavepointAppleMusicDemo` defaults to eligible and maps these values to the existing eligibility states: `permission-denied`, `account-not-ready`, `service-unavailable`, `subscription-required`, and `sync-library-required`. Assert no argument returns nil.

**Step 2: Run focused tests and verify RED**

Expected: `AppleMusicSimulatorDemo` does not exist.

**Step 3: Implement the harness**

Wrap the entire file and its integration branch in:

```swift
#if DEBUG && targetEnvironment(simulator)
// demo-only types and composition
#endif
```

For eligible mode, provide deterministic Apple Music `LibraryTrack` values, an in-memory Dumpster commit result, a selection store fixed to Apple Music, and a no-op successful `AppleMusicPlayerClient`. Inject these at the same external boundaries as real MusicKit; keep `AppRootView` and all state models unchanged.

**Step 4: Run focused tests and launch Simulator**

Launch with:

```bash
xcrun simctl launch <booted-udid> ai.mapier.swipe \
  -WavepointAppleMusicDemo eligible
```

Verify provider routing, deck, automatic playback state, keep/remove, undo, review, Dumpster completion, and Start Again. Repeat each blocker scenario and verify its accessibility identifier.

**Step 5: Commit**

```bash
git commit -m "feat(ios): add Apple Music simulator QA mode"
```

### Task 4: Release verification and TestFlight

**Files:**
- Modify: `ios/project.yml`
- Modify generated: `ios/Wavepoint.xcodeproj/project.pbxproj`
- Modify: `ios/WavepointTests/ProjectConfigurationTests.swift`
- Modify: `release/README.md` only if the recorded build changes

**Step 1: Update the version test to build 7 and verify RED**

**Step 2: Set `CURRENT_PROJECT_VERSION: 7` and regenerate**

```bash
cd ios && xcodegen generate
```

**Step 3: Run all release gates**

```bash
xcodebuild test -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination '<available simulator>'
xcodebuild archive -project ios/Wavepoint.xcodeproj -scheme Wavepoint -destination 'generic/platform=iOS' -archivePath /tmp/Wavepoint.xcarchive CODE_SIGNING_ALLOWED=NO
cd android && ./gradlew testDebugUnitTest lintDebug bundleRelease lintRelease
deno fmt --check supabase/functions && deno test supabase/functions
```

**Step 4: Create the signed archive and upload**

Use automatic signing for team `HV58968J2R`, export with the existing App Store Connect configuration, upload, and wait for App Store Connect to accept processing.

**Step 5: Commit and push**

```bash
git commit -m "build(ios): publish Apple Music test build 7"
git push origin codex/swipe-design-html
```

**Step 6: Physical-device handoff**

Test: eligible subscriber with Sync Library, Sync off, permission denied, account/setup pending, service unavailable, autoplay across three cards, first Dumpster creation, and a later append after deleting an older Dumpster song.
