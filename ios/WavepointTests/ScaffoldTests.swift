import XCTest
@testable import Wavepoint

final class ScaffoldTests: XCTestCase {
  func testAppConfigurationIsAValueType() {
    let url = URL(string: "https://example.supabase.co")!
    let callbackURL = URL(string: "ai.mapier.swipe://login-callback")!
    let configuration = AppConfiguration(
      supabaseURL: url,
      supabasePublishableKey: "publishable",
      callbackURL: callbackURL,
      spotifyClientID: "spotify-client",
      spotifyAppRemoteCallbackURL: URL(
        string: "ai.mapier.swipe://spotify-app-remote-callback"
      )!
    )

    XCTAssertEqual(configuration.callbackURL, callbackURL)
    XCTAssertEqual(configuration.spotifyClientID, "spotify-client")
    XCTAssertEqual(
      configuration.spotifyAppRemoteCallbackURL.absoluteString,
      "ai.mapier.swipe://spotify-app-remote-callback"
    )
  }
}
