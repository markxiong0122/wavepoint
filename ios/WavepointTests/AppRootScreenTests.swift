import XCTest
@testable import Wavepoint

final class AppRootScreenTests: XCTestCase {
  func testSessionStatesMapToAccessibleRootScreens() {
    XCTAssertEqual(AppRootScreen(state: .restoring).accessibilityIdentifier, "auth-progress")
    XCTAssertEqual(AppRootScreen(state: .signedOut).accessibilityIdentifier, "spotify-login-button")
    XCTAssertEqual(AppRootScreen(state: .authorizing).accessibilityIdentifier, "auth-progress")
    XCTAssertEqual(AppRootScreen(state: .deletingAccount).accessibilityIdentifier, "auth-progress")
    XCTAssertEqual(AppRootScreen(state: .signedIn).accessibilityIdentifier, "cleanup-home")
    XCTAssertEqual(AppRootScreen(state: .failed("Try again")).accessibilityIdentifier, "auth-error")
  }
}
