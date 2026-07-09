import XCTest
@testable import Wavepoint

final class ScaffoldTests: XCTestCase {
  func testAppConfigurationIsAValueType() {
    let url = URL(string: "https://example.supabase.co")!
    let callbackURL = URL(string: "ai.mapier.swipe://login-callback")!
    let configuration = AppConfiguration(
      supabaseURL: url,
      supabasePublishableKey: "publishable",
      callbackURL: callbackURL
    )

    XCTAssertEqual(configuration.callbackURL, callbackURL)
  }
}
