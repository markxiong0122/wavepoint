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

  func testProviderAndSessionStatesRouteTheWholeApp() {
    XCTAssertEqual(
      AppRootScreen(providerState: .restoring, spotifyState: .signedOut),
      .progress
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .providerPicker, spotifyState: .signedOut),
      .providerPicker
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .spotifySelected, spotifyState: .signedOut),
      .login
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .spotifySelected, spotifyState: .signedIn),
      .cleanup(.spotify)
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .authorizingAppleMusic, spotifyState: .signedOut),
      .progress
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .appleMusicReady, spotifyState: .signedOut),
      .cleanup(.appleMusic)
    )
  }

  func testAppleMusicEligibilityStatesRouteToSpecificRecoveryScreens() {
    XCTAssertEqual(
      AppRootScreen(providerState: .appleMusicPermissionDenied, spotifyState: .signedOut),
      .appleMusicPermissionDenied
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .appleMusicRestricted, spotifyState: .signedOut),
      .appleMusicRestricted
    )
    XCTAssertEqual(
      AppRootScreen(
        providerState: .appleMusicPrivacyAcknowledgementRequired,
        spotifyState: .signedOut
      ),
      .appleMusicPrivacyAcknowledgementRequired
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .appleMusicAccountNotReady, spotifyState: .signedOut),
      .appleMusicAccountNotReady
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .appleMusicServiceUnavailable, spotifyState: .signedOut),
      .appleMusicServiceUnavailable
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .appleMusicSubscriptionRequired, spotifyState: .signedOut),
      .appleMusicSubscriptionRequired
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .appleMusicSyncLibraryRequired, spotifyState: .signedOut),
      .appleMusicSyncLibraryRequired
    )
    XCTAssertEqual(
      AppRootScreen(providerState: .failed("No music"), spotifyState: .signedOut),
      .error("No music")
    )
  }
}
