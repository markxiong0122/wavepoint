import XCTest
@testable import Wavepoint

final class SpotifyCredentialProviderTests: XCTestCase {
  func testUsesStoredAccessTokenWithoutRefreshing() async throws {
    let store = CredentialMemoryStore(
      tokens: .init(accessToken: "stored-access", refreshToken: "stored-refresh")
    )
    let refreshService = CredentialRefreshService()
    let provider = SpotifyCredentialProvider(
      tokenStore: store,
      refreshService: refreshService
    )

    let token = try await provider.accessToken(forceRefresh: false)

    XCTAssertEqual(token, "stored-access")
    let calls = await refreshService.refreshTokens
    XCTAssertTrue(calls.isEmpty)
  }

  func testForcedRefreshStoresNewAccessAndRotatedRefreshToken() async throws {
    let store = CredentialMemoryStore(
      tokens: .init(accessToken: "old-access", refreshToken: "old-refresh")
    )
    let refreshService = CredentialRefreshService(
      result: .init(
        accessToken: "new-access",
        refreshToken: "new-refresh",
        expiresIn: 3600
      )
    )
    let provider = SpotifyCredentialProvider(
      tokenStore: store,
      refreshService: refreshService
    )

    let token = try await provider.accessToken(forceRefresh: true)

    XCTAssertEqual(token, "new-access")
    XCTAssertEqual(
      try store.load(),
      SpotifyProviderTokens(accessToken: "new-access", refreshToken: "new-refresh")
    )
    let calls = await refreshService.refreshTokens
    XCTAssertEqual(calls, ["old-refresh"])
  }

  func testForcedRefreshWithoutRefreshTokenRequiresReconnect() async {
    let provider = SpotifyCredentialProvider(
      tokenStore: CredentialMemoryStore(
        tokens: .init(accessToken: "access", refreshToken: nil)
      ),
      refreshService: CredentialRefreshService()
    )

    do {
      _ = try await provider.accessToken(forceRefresh: true)
      XCTFail("Expected authorizationExpired")
    } catch {
      XCTAssertEqual(error as? SpotifyWebAPIError, .authorizationExpired)
    }
  }
}

private final class CredentialMemoryStore: SpotifyTokenStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var storedTokens: SpotifyProviderTokens?

  init(tokens: SpotifyProviderTokens?) {
    storedTokens = tokens
  }

  func save(_ tokens: SpotifyProviderTokens) throws {
    lock.withLock { storedTokens = tokens }
  }

  func load() throws -> SpotifyProviderTokens? {
    lock.withLock { storedTokens }
  }

  func delete() throws {
    lock.withLock { storedTokens = nil }
  }
}

private actor CredentialRefreshService: SpotifyTokenRefreshServing {
  private(set) var refreshTokens: [String] = []
  private let result: RefreshedSpotifyToken

  init(
    result: RefreshedSpotifyToken = .init(
      accessToken: "unused",
      refreshToken: nil,
      expiresIn: 3600
    )
  ) {
    self.result = result
  }

  func refresh(providerRefreshToken: String) async throws -> RefreshedSpotifyToken {
    refreshTokens.append(providerRefreshToken)
    return result
  }
}
