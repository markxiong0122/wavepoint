import XCTest
@testable import Wavepoint

final class AnalyticsEventTests: XCTestCase {
  func testEventContractUsesOnlyApprovedNamesAndProperties() {
    let events: [(AnalyticsEvent, String, [String: String])] = [
      (.appOpened, "app_opened", [:]),
      (.providerPickerViewed, "provider_picker_viewed", [:]),
      (
        .providerConnectionStarted(.spotify),
        "provider_connection_started",
        ["provider": "spotify"]
      ),
      (
        .providerConnectionSucceeded(.appleMusic),
        "provider_connection_succeeded",
        ["provider": "apple_music"]
      ),
      (
        .providerConnectionFailed(.spotify, .authorization),
        "provider_connection_failed",
        ["provider": "spotify", "error_category": "authorization"]
      ),
      (.cleanupDeckLoaded(.spotify), "cleanup_deck_loaded", ["provider": "spotify"]),
      (
        .firstDecisionCompleted(.spotify),
        "first_decision_completed",
        ["provider": "spotify"]
      ),
      (.reviewOpened(.spotify), "review_opened", ["provider": "spotify"]),
      (
        .cleanupSessionCompleted(.appleMusic),
        "cleanup_session_completed",
        ["provider": "apple_music"]
      ),
      (
        .cleanupSessionAbandoned(.spotify),
        "cleanup_session_abandoned",
        ["provider": "spotify"]
      ),
      (.accountDeleted, "account_deleted", [:]),
    ]

    for (event, name, properties) in events {
      XCTAssertEqual(event.name, name)
      XCTAssertEqual(event.properties, properties)
      XCTAssertTrue(Set(event.properties.keys).isSubset(of: ["provider", "error_category"]))
    }
  }

  func testClientForwardsOnlyTheClosedEventPayload() {
    var capturedName: String?
    var capturedProperties: [String: String]?
    let client = AnalyticsClient { name, properties in
      capturedName = name
      capturedProperties = properties
    }

    client.capture(.providerConnectionFailed(.spotify, .eligibility))

    XCTAssertEqual(capturedName, "provider_connection_failed")
    XCTAssertEqual(
      capturedProperties,
      ["provider": "spotify", "error_category": "eligibility"]
    )
  }

  func testSettingsRequireBothAProjectTokenAndHTTPSHost() {
    XCTAssertFalse(AnalyticsSettings(projectToken: "", host: "https://us.i.posthog.com").isEnabled)
    XCTAssertFalse(AnalyticsSettings(projectToken: "phc_test", host: "http://example.com").isEnabled)
    XCTAssertTrue(
      AnalyticsSettings(projectToken: "phc_test", host: "https://us.i.posthog.com").isEnabled
    )
  }
}
