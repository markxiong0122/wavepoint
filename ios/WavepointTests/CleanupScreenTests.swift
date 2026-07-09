import XCTest
@testable import Wavepoint

final class CleanupScreenTests: XCTestCase {
  func testStateMapsToStableAccessibleScreen() {
    XCTAssertEqual(CleanupScreen(state: .idle).accessibilityIdentifier, "cleanup-loading")
    XCTAssertEqual(CleanupScreen(state: .loading).accessibilityIdentifier, "cleanup-loading")
    XCTAssertEqual(CleanupScreen(state: .deciding).accessibilityIdentifier, "cleanup-deck")
    XCTAssertEqual(CleanupScreen(state: .reviewing).accessibilityIdentifier, "cleanup-review")
    XCTAssertEqual(CleanupScreen(state: .committing).accessibilityIdentifier, "cleanup-committing")
    XCTAssertEqual(
      CleanupScreen(state: .complete(.init(decisionCount: 2, removedCount: 1)))
        .accessibilityIdentifier,
      "cleanup-complete"
    )
    XCTAssertEqual(
      CleanupScreen(state: .failed("Try again")).accessibilityIdentifier,
      "cleanup-error"
    )
  }
}
