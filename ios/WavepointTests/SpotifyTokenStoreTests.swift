import XCTest
@testable import Wavepoint

final class SpotifyTokenStoreTests: XCTestCase {
  private var store: KeychainSpotifyTokenStore!

  override func setUp() {
    super.setUp()
    store = KeychainSpotifyTokenStore(
      service: "ai.mapier.swipe.tests.\(UUID().uuidString)",
      account: "provider-tokens"
    )
  }

  override func tearDown() {
    try? store.delete()
    store = nil
    super.tearDown()
  }

  func testSaveThenLoadReturnsProviderTokens() throws {
    let expected = SpotifyProviderTokens(
      accessToken: "access",
      refreshToken: "refresh"
    )

    try store.save(expected)

    XCTAssertEqual(try store.load(), expected)
  }

  func testSavingAgainReplacesProviderTokens() throws {
    try store.save(
      SpotifyProviderTokens(accessToken: "old", refreshToken: "old-refresh")
    )

    let replacement = SpotifyProviderTokens(
      accessToken: "new",
      refreshToken: "new-refresh"
    )
    try store.save(replacement)

    XCTAssertEqual(try store.load(), replacement)
  }

  func testDeleteRemovesProviderTokens() throws {
    try store.save(
      SpotifyProviderTokens(accessToken: "access", refreshToken: "refresh")
    )

    try store.delete()

    XCTAssertNil(try store.load())
  }
}
