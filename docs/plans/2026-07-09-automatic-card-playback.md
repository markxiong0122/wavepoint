# Automatic Card Playback Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep Supabase login, automatically open Spotify with the first cleanup track, and autoplay a 15-second segment for every card without per-card play taps.

**Architecture:** Add a small `@MainActor` cleanup playback coordinator that owns the existing `TrackPreviewPlayer` for the whole cleanup session. `CleanupHomeView` drives the coordinator from track/state lifecycle changes, while `TrackCardView` becomes a presentation/control surface for the injected shared player. The first and following automatic starts force Spotify App Remote; manual fallback preserves the existing direct-preview-first behavior.

**Tech Stack:** Swift 6, SwiftUI Observation, Spotify iOS SDK 5.0.1 App Remote, AVFoundation, XCTest, XcodeGen.

---

### Task 1: Add the cleanup playback coordinator

**Files:**
- Create: `ios/Wavepoint/Cleanup/CleanupPlaybackCoordinator.swift`
- Create: `ios/WavepointTests/CleanupPlaybackCoordinatorTests.swift`
- Modify: `ios/Wavepoint.xcodeproj/project.pbxproj` via XcodeGen

**Step 1: Write the failing first-track test**

Create a real `TrackPreviewPlayer` with recording preview and remote engines. The first test should prepare a track that has both a direct preview and Spotify URI, call `present(_:)`, and prove automatic setup forces the remote source:

```swift
func testFirstTrackStartsSpotifyRemoteAndEnablesAutomaticMode() async {
  let remote = RecordingRemotePlayer()
  let player = TrackPreviewPlayer(engine: RecordingPreviewEngine(), remote: remote)
  let coordinator = CleanupPlaybackCoordinator(player: player)
  let track = spotifyTrack(id: "first", previewURL: URL(string: "https://audio.example/first.mp3"))

  await coordinator.present(track)

  XCTAssertEqual(coordinator.state, .automatic)
  XCTAssertEqual(player.source, .spotifyRemote)
  XCTAssertEqual(player.state, .playing)
  XCTAssertEqual(remote.events, [.play("spotify:track:first")])
}
```

Add tests proving:

- a second track pauses the first before playing the next URI;
- presenting the current playing track is a no-op;
- a first-track error produces `.failed(message)`;
- `continueManually(with:)` prepares the direct preview without starting it;
- an automatic error after the deck has started falls back to `.manual`.

**Step 2: Generate the project and verify RED**

Run:

```bash
cd ios && xcodegen generate
DEVELOPER_DIR=/Users/mark/Downloads/Xcode-beta.app/Contents/Developer \
  xcodebuild test -quiet -project Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'platform=iOS Simulator,id=3D75011D-9246-4166-91F5-D8CC9316909D' \
  -derivedDataPath ../build/test27-derived \
  -only-testing:WavepointTests/CleanupPlaybackCoordinatorTests
```

Expected: FAIL because `CleanupPlaybackCoordinator` does not exist.

**Step 3: Implement the minimal coordinator**

Use this state and public surface:

```swift
enum CleanupPlaybackState: Equatable, Sendable {
  case idle
  case starting
  case automatic
  case manual
  case failed(String)
}

@MainActor
@Observable
final class CleanupPlaybackCoordinator {
  private(set) var state: CleanupPlaybackState = .idle
  let player: TrackPreviewPlayer

  private var currentTrackID: String?
  private var hasStartedDeck = false

  init(player: TrackPreviewPlayer) {
    self.player = player
  }

  func present(_ track: SpotifyTrack) async
  func retry(_ track: SpotifyTrack) async
  func continueManually(with track: SpotifyTrack) async
  func stop() async
}
```

`present(_:)` must stop an outgoing track, prepare with `previewURL: nil` in automatic mode, and call `togglePlayback()`. Only the first start uses `.starting`; later transitions keep the deck visible. A failed first start sets `.failed(localizedMessage)`. A later failure prepares the actual preview/URI and switches to `.manual`.

**Step 4: Verify GREEN**

Run the focused command from Step 2.

Expected: all coordinator tests PASS.

**Step 5: Commit**

```bash
git add ios/Wavepoint/Cleanup/CleanupPlaybackCoordinator.swift \
  ios/WavepointTests/CleanupPlaybackCoordinatorTests.swift \
  ios/Wavepoint.xcodeproj/project.pbxproj
git commit -m "feat: coordinate automatic cleanup playback"
```

### Task 2: Make stale playback starts harmless

**Files:**
- Modify: `ios/Wavepoint/Audio/TrackPreviewPlayer.swift`
- Modify: `ios/WavepointTests/TrackPreviewPlayerTests.swift`

**Step 1: Write the failing stale-start test**

Use a controllable remote whose first `play(uri:)` suspends. Start track A, prepare track B before A completes, then release A. Assert that A cannot set the shared player back to `.playing` or schedule B's timer.

```swift
func testPreparingNewTrackInvalidatesPendingRemoteStart() async {
  let remote = ControlledRemotePlayer()
  let player = TrackPreviewPlayer(engine: RecordingPreviewEngine(), remote: remote)
  player.prepare(previewURL: nil, spotifyURI: "spotify:track:a")

  let oldStart = Task { await player.togglePlayback() }
  await remote.waitUntilPlayStarts()
  player.prepare(previewURL: nil, spotifyURI: "spotify:track:b")
  remote.finishPlay()
  await oldStart.value

  XCTAssertEqual(player.state, .ready)
}
```

**Step 2: Run the test to verify RED**

Run the `TrackPreviewPlayerTests` suite.

Expected: FAIL because the stale completion sets `.playing`.

**Step 3: Add a generation guard**

Increment a private playback generation in `prepare` and `stop`. Capture it before awaiting remote play, then return without changing state or scheduling a timer when the captured generation is stale.

**Step 4: Verify GREEN**

Run `TrackPreviewPlayerTests` and `CleanupPlaybackCoordinatorTests`.

Expected: both suites PASS.

**Step 5: Commit**

```bash
git add ios/Wavepoint/Audio/TrackPreviewPlayer.swift \
  ios/WavepointTests/TrackPreviewPlayerTests.swift
git commit -m "fix: ignore stale cleanup playback starts"
```

### Task 3: Share the player with every card

**Files:**
- Modify: `ios/Wavepoint/Features/Cleanup/TrackCardView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Modify: `ios/WavepointTests/CleanupScreenTests.swift`

**Step 1: Write failing screen-state tests**

Add a pure mapping used by `CleanupHomeView`:

```swift
enum CleanupPlaybackScreen: Equatable {
  case starting
  case deck
  case failed(String)

  init(state: CleanupPlaybackState) {
    switch state {
    case .idle, .starting: self = .starting
    case .automatic, .manual: self = .deck
    case .failed(let message): self = .failed(message)
    }
  }
}
```

Test all mappings before adding the enum.

**Step 2: Verify RED**

Run `CleanupScreenTests`.

Expected: FAIL because `CleanupPlaybackScreen` does not exist.

**Step 3: Inject the shared player**

Change `TrackCardView` to accept `TrackPreviewPlayer` directly:

```swift
struct TrackCardView: View {
  let track: SpotifyTrack
  let previewPlayer: TrackPreviewPlayer
  // existing position/actions
}
```

Remove its private player construction, `.onAppear` preparation, and `.onDisappear` stop. Keep the audio button as pause/resume/manual play.

`CleanupHomeView` creates one coordinator in its initializer:

```swift
@State private var playback: CleanupPlaybackCoordinator

_playback = State(
  initialValue: CleanupPlaybackCoordinator(
    player: TrackPreviewPlayer(remote: remotePlayback)
  )
)
```

Pass `playback.player` into every card.

**Step 4: Add starting and failure surfaces**

While playback is `.idle` or `.starting`, show the existing mark/progress treatment with `STARTING AUTOPLAY…`. On `.failed`, show the message plus `TRY AGAIN` and `CONTINUE WITHOUT AUTOPLAY`. Preserve the deck for `.automatic` and `.manual`.

**Step 5: Verify GREEN**

Run `CleanupScreenTests`, then build the app.

Expected: tests PASS and Debug build succeeds without warnings.

**Step 6: Commit**

```bash
git add ios/Wavepoint/Features/Cleanup/TrackCardView.swift \
  ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift \
  ios/WavepointTests/CleanupScreenTests.swift
git commit -m "feat: share playback across cleanup cards"
```

### Task 4: Drive playback from cleanup lifecycle

**Files:**
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Modify: `ios/WavepointTests/CleanupPlaybackCoordinatorTests.swift`

**Step 1: Add failing lifecycle tests**

Add coordinator tests proving `stop()` pauses active Spotify playback and that presenting the same track after a stop resumes it. This covers leaving for Review and returning without a track-ID change.

**Step 2: Verify RED**

Run `CleanupPlaybackCoordinatorTests`.

Expected: the resume-after-stop assertion FAILS until coordinator state is handled.

**Step 3: Add lifecycle tasks**

In `CleanupHomeView`, use `.task(id:)` keyed by current track plus cleanup screen. When `.deciding`, call `playback.present(track)`. For review, commit, complete, error, and disappearance, call `playback.stop()`.

Do not place service calls in `body`, gesture callbacks, or the cleanup model.

**Step 4: Verify GREEN**

Run the coordinator, playback, cleanup-model, and cleanup-screen suites.

Expected: all focused suites PASS.

**Step 5: Commit**

```bash
git add ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift \
  ios/WavepointTests/CleanupPlaybackCoordinatorTests.swift
git commit -m "feat: autoplay active cleanup tracks"
```

### Task 5: Update user-facing documentation

**Files:**
- Modify: `docs/privacy.html`
- Modify: `ios/README.md`
- Modify: `docs/plans/2026-07-09-hybrid-playback-account-deletion.md`

**Step 1: Update playback disclosure**

Replace the statement that playback happens only after a per-card listening-control tap. State that Spotify may open automatically after login/deck loading to establish playback, and that Wavepoint controls 15-second segments during an active cleanup session.

**Step 2: Update device setup and QA notes**

Document both redirect URIs:

```text
https://pvlykxebusgsgrtrkrqh.supabase.co/auth/v1/callback
ai.mapier.swipe://spotify-app-remote-callback
```

Add the physical-device autoplay checkpoint.

**Step 3: Commit**

```bash
git add docs/privacy.html ios/README.md \
  docs/plans/2026-07-09-hybrid-playback-account-deletion.md
git commit -m "docs: disclose automatic Spotify playback"
```

### Task 6: Verify on Simulator and iPhone

**Files:**
- Modify only if verification exposes a defect.

**Step 1: Run the full automated suite**

```bash
DEVELOPER_DIR=/Users/mark/Downloads/Xcode-beta.app/Contents/Developer \
  xcodebuild test -quiet -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -destination 'platform=iOS Simulator,id=3D75011D-9246-4166-91F5-D8CC9316909D' \
  -derivedDataPath build/test27-derived
```

Expected: every test PASS.

**Step 2: Build and install on iPhone 61**

```bash
DEVELOPER_DIR=/Users/mark/Downloads/Xcode-beta.app/Contents/Developer \
  xcodebuild build -quiet -project ios/Wavepoint.xcodeproj -scheme Wavepoint \
  -configuration Debug -destination 'platform=iOS,id=00008140-0012253802F0801C' \
  -derivedDataPath build/device27-derived -allowProvisioningUpdates

DEVELOPER_DIR=/Users/mark/Downloads/Xcode-beta.app/Contents/Developer \
  xcrun devicectl device install app \
  --device C622076C-BCB9-5FCE-BD44-5EB6A056B5BC \
  build/device27-derived/Build/Products/Debug-iphoneos/Wavepoint.app
```

**Step 3: Exercise the safe device flow**

Verify:

- library load automatically opens Spotify with the first cleanup track;
- callback returns to the matching first card without restarting it;
- three Keep/Remove/Undo transitions each autoplay the matching card;
- pause/resume and the 15-second stop work;
- no extra Spotify switch occurs while App Remote stays connected;
- Review stops playback and Cancel resumes the current card;
- no removal batch is confirmed during QA.

**Step 4: Run the simplify and verification skills**

Run `simplify` over only the modified autoplay files, then run `superpowers:verification-before-completion` with fresh test/build evidence.

**Step 5: Prepare App Store build 3**

After device verification, increment `CURRENT_PROJECT_VERSION` from 2 to 3, archive/export the signed IPA, verify its signature/privacy manifests/icon, and commit only the version/release metadata:

```bash
git commit -m "chore: prepare App Store build 3"
```
