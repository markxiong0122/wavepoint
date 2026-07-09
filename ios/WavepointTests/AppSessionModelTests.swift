import XCTest
@testable import Wavepoint

@MainActor
final class AppSessionModelTests: XCTestCase {
  func testRestoreWithoutSupabaseSessionBecomesSignedOut() async {
    let authenticator = FakeSpotifyAuthenticator(currentSession: nil)
    let model = AppSessionModel(
      authenticator: authenticator,
      tokenStore: InMemorySpotifyTokenStore()
    )

    await model.restore()

    XCTAssertEqual(model.state, .signedOut)
  }

  func testSignInMovesThroughAuthorizingThenSavesTokens() async {
    let tokens = SpotifyProviderTokens(
      accessToken: "access",
      refreshToken: "refresh"
    )
    let authenticator = FakeSpotifyAuthenticator(
      signInSession: SpotifyAuthSession(providerTokens: tokens),
      signInDelay: .milliseconds(50)
    )
    let tokenStore = InMemorySpotifyTokenStore()
    let model = AppSessionModel(
      authenticator: authenticator,
      tokenStore: tokenStore,
      initialState: .signedOut
    )

    let task = Task { await model.signIn() }
    while model.state == .signedOut {
      await Task.yield()
    }

    XCTAssertEqual(model.state, .authorizing)
    await task.value
    XCTAssertEqual(model.state, .signedIn)
    XCTAssertEqual(tokenStore.tokens, tokens)
  }

  func testSignInWithoutProviderAccessTokenShowsRecoverableError() async {
    let authenticator = FakeSpotifyAuthenticator(
      signInSession: SpotifyAuthSession(providerTokens: nil)
    )
    let model = AppSessionModel(
      authenticator: authenticator,
      tokenStore: InMemorySpotifyTokenStore(),
      initialState: .signedOut
    )

    await model.signIn()

    XCTAssertEqual(
      model.state,
      .failed("Spotify did not return an access token. Please try connecting again.")
    )
  }

  func testSignOutClearsSupabaseSessionAndStoredTokens() async throws {
    let authenticator = FakeSpotifyAuthenticator()
    let tokenStore = InMemorySpotifyTokenStore()
    try tokenStore.save(
      SpotifyProviderTokens(accessToken: "access", refreshToken: "refresh")
    )
    let model = AppSessionModel(
      authenticator: authenticator,
      tokenStore: tokenStore,
      initialState: .signedIn
    )

    await model.signOut()

    XCTAssertEqual(model.state, .signedOut)
    XCTAssertNil(tokenStore.tokens)
    let signOutCallCount = await authenticator.signOutCallCount
    XCTAssertEqual(signOutCallCount, 1)
  }
}

private actor FakeSpotifyAuthenticator: SpotifyAuthenticating {
  var signOutCallCount = 0

  private let currentSession: SpotifyAuthSession?
  private let signInSession: SpotifyAuthSession
  private let signInDelay: Duration

  init(
    currentSession: SpotifyAuthSession? = nil,
    signInSession: SpotifyAuthSession = SpotifyAuthSession(providerTokens: nil),
    signInDelay: Duration = .zero
  ) {
    self.currentSession = currentSession
    self.signInSession = signInSession
    self.signInDelay = signInDelay
  }

  func restoreSession() async throws -> SpotifyAuthSession? {
    currentSession
  }

  func signIn() async throws -> SpotifyAuthSession {
    try await Task.sleep(for: signInDelay)
    return signInSession
  }

  func signOut() async throws {
    signOutCallCount += 1
  }
}

private final class InMemorySpotifyTokenStore: SpotifyTokenStoring, @unchecked Sendable {
  var tokens: SpotifyProviderTokens?

  func save(_ tokens: SpotifyProviderTokens) throws {
    self.tokens = tokens
  }

  func load() throws -> SpotifyProviderTokens? {
    tokens
  }

  func delete() throws {
    tokens = nil
  }
}
