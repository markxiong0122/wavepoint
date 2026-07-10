import XCTest
@testable import Wavepoint

final class AppRootScreenTests: XCTestCase {
  func testSessionStatesMapToAccessibleRootScreens() {
    XCTAssertEqual(AppRootScreen(state: .restoring).accessibilityIdentifier, "auth-progress")
    XCTAssertEqual(AppRootScreen(state: .signedOut).accessibilityIdentifier, "spotify-login-button")
    XCTAssertEqual(AppRootScreen(state: .authorizing).accessibilityIdentifier, "auth-progress")
    XCTAssertEqual(AppRootScreen(state: .deletingAccount).accessibilityIdentifier, "auth-progress")
    XCTAssertEqual(AppRootScreen(state: .signedIn).accessibilityIdentifier, "cleanup-home")
    XCTAssertEqual(
      AppRootScreen(state: .spotifyPremiumRequired).accessibilityIdentifier,
      "spotify-premium-required"
    )
    XCTAssertEqual(
      AppRootScreen(state: .spotifyReconnectRequired).accessibilityIdentifier,
      "spotify-reconnect-required"
    )
    XCTAssertEqual(
      AppRootScreen(state: .spotifyEligibilityUnavailable).accessibilityIdentifier,
      "spotify-eligibility-unavailable"
    )
    XCTAssertEqual(AppRootScreen(state: .failed("Try again")).accessibilityIdentifier, "auth-error")
  }
}
