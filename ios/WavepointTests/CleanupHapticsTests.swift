import XCTest

@testable import Wavepoint

@MainActor
final class CleanupHapticsTests: XCTestCase {
  func testEventsMapToDistinctFeedback() {
    let recorder = HapticActionRecorder()
    let haptics = CleanupHaptics(
      isEnabled: true,
      selection: recorder.selection,
      mediumImpact: recorder.mediumImpact,
      heavyImpact: recorder.heavyImpact,
      lightImpact: recorder.lightImpact,
      success: recorder.success
    )

    haptics.play(.threshold)
    haptics.play(.keep)
    haptics.play(.remove)
    haptics.play(.undo)
    haptics.play(.success)

    XCTAssertEqual(recorder.events, [.threshold, .keep, .remove, .undo, .success])
  }

  func testDisabledHapticsAreANoOp() {
    let recorder = HapticActionRecorder()
    let haptics = CleanupHaptics(
      isEnabled: false,
      selection: recorder.selection,
      mediumImpact: recorder.mediumImpact,
      heavyImpact: recorder.heavyImpact,
      lightImpact: recorder.lightImpact,
      success: recorder.success
    )

    haptics.play(.remove)

    XCTAssertTrue(recorder.events.isEmpty)
  }

  func testSwipeThresholdFiresOnceUntilGestureEnds() {
    var feedback = SwipeThresholdFeedback()

    XCTAssertFalse(feedback.update(distance: 80, threshold: 100))
    XCTAssertTrue(feedback.update(distance: 110, threshold: 100))
    XCTAssertFalse(feedback.update(distance: 150, threshold: 100))

    feedback.reset()

    XCTAssertTrue(feedback.update(distance: -120, threshold: 100))
  }
}

@MainActor
private final class HapticActionRecorder {
  private(set) var events: [CleanupHapticEvent] = []

  func selection() { events.append(.threshold) }
  func mediumImpact() { events.append(.keep) }
  func heavyImpact() { events.append(.remove) }
  func lightImpact() { events.append(.undo) }
  func success() { events.append(.success) }
}
