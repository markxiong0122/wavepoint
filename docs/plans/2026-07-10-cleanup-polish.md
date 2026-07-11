# Cleanup Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Recover Spotify autoplay after transient card failures, guarantee card/action separation, and add subtle cleanup haptics.

**Architecture:** Keep playback policy in `CleanupPlaybackCoordinator`, keep adaptive sizing in a small pure layout policy consumed by SwiftUI, and inject a minimal haptic client into `CleanupHomeView`/`TrackCardView`. Preserve the current cleanup domain and provider-neutral card model.

**Tech Stack:** Swift 6, SwiftUI, Observation, XCTest, Spotify iOS App Remote.

---

### Task 1: Recover automatic playback

**Files:**
- Modify: `ios/WavepointTests/CleanupPlaybackCoordinatorTests.swift`
- Modify: `ios/Wavepoint/Cleanup/CleanupPlaybackCoordinator.swift`

1. Change the later-failure regression test to require manual playback only for the failed card and a new automatic attempt for the next card.
2. Add a separate test proving explicit `continueManually` remains sticky.
3. Run the two focused tests and confirm the recovery test fails before implementation.
4. Separate transient fallback from explicit manual preference with the minimum coordinator state needed.
5. Run `CleanupPlaybackCoordinatorTests` and confirm all pass.
6. Commit as `fix(ios): recover cleanup autoplay after track failure`.

### Task 2: Protect the action bar from card content

**Files:**
- Create: `ios/Wavepoint/Features/Cleanup/CleanupCardLayout.swift`
- Create: `ios/WavepointTests/CleanupCardLayoutTests.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/TrackCardView.swift`

1. Write pure layout-policy tests covering the current iPhone height, a shorter supported height, and long two-line titles; assert a non-negative artwork height and reserved action-bar gap.
2. Run the focused test and confirm it fails because the policy does not exist.
3. Implement a small `CleanupCardLayout` calculation that assigns remaining height to artwork after fixed metadata and controls.
4. Apply it through the deck's `GeometryReader`; give `TrackCardView` an explicit height and artwork height, with metadata using fixed vertical sizing.
5. Remove the extra Spotify connection-hint row from the card.
6. Run layout and existing screen tests.
7. Commit as `fix(ios): keep cleanup cards above actions`.

### Task 3: Add tactile cleanup feedback

**Files:**
- Create: `ios/Wavepoint/Design/CleanupHaptics.swift`
- Create: `ios/WavepointTests/CleanupHapticsTests.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/CleanupHomeView.swift`
- Modify: `ios/Wavepoint/Features/Cleanup/TrackCardView.swift`

1. Write tests for the event-to-generator mapping and for disabled/no-op behavior.
2. Run the focused test and confirm it fails because the haptic client does not exist.
3. Implement a main-actor haptic client using selection, impact, and notification generators.
4. Trigger threshold, decision, undo, and commit-success feedback exactly once at their UI action boundaries.
5. Run the haptic and cleanup session tests.
6. Commit as `feat(ios): add cleanup decision haptics`.

### Task 4: Verify and deploy to the connected iPhone

**Files:**
- Modify only if verification exposes a reproducible defect.

1. Run the complete iOS test suite with normal simulator signing.
2. Build a signed Debug app for iPhone 61.
3. Install and launch it without clearing app data.
4. Verify autoplay across at least four card transitions, including recovery after a simulated/transient failure when reproducible.
5. Capture the previously failing card and confirm the card bottom remains above the action buttons.
6. Verify Keep, Remove, Undo, threshold crossing, and completion haptics on hardware.
7. Shut down simulators and build daemons, then push all small commits.
