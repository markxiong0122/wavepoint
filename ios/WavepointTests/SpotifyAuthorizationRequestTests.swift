import Supabase
import XCTest
@testable import Wavepoint

final class SpotifyAuthorizationRequestTests: XCTestCase {
  func testRequestUsesSpotifyCallbackAndCleanupScopes() throws {
    let request = try SpotifyAuthorizationRequest(
      callbackURL: XCTUnwrap(URL(string: "ai.mapier.swipe://login-callback"))
    )

    XCTAssertEqual(request.provider, .spotify)
    XCTAssertEqual(request.callbackURL.absoluteString, "ai.mapier.swipe://login-callback")
    XCTAssertEqual(
      request.scopes,
      "user-read-email user-read-private user-library-read user-library-modify "
        + "user-read-recently-played app-remote-control"
    )
    XCTAssertEqual(request.callbackScheme, "ai.mapier.swipe")
  }
}
