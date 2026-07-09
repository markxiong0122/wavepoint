import XCTest
@testable import Wavepoint

@MainActor
final class AppSessionModelTests: XCTestCase {
  func testRestoreWithoutSupabaseSessionBecomesSignedOut() async {
    let authenticator = FakeSpotifyAuthenticator(currentSession: nil)
    let model = AppSessionModel(
      authenticator: authenticator,
      tokenStore: InMemorySpotifyTokenStore(),
      accountDeleter: FakeAccountDeletionService()
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
      accountDeleter: FakeAccountDeletionService(),
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
      accountDeleter: FakeAccountDeletionService(),
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
      accountDeleter: FakeAccountDeletionService(),
      initialState: .signedIn
    )

    await model.signOut()

    XCTAssertEqual(model.state, .signedOut)
    XCTAssertNil(tokenStore.tokens)
    let signOutCallCount = await authenticator.signOutCallCount
    XCTAssertEqual(signOutCallCount, 1)
  }

  func testDeleteAccountShowsProgressThenClearsAllLocalCredentials() async throws {
    let authenticator = FakeSpotifyAuthenticator()
    let deletionService = FakeAccountDeletionService(delay: .milliseconds(40))
    let tokenStore = InMemorySpotifyTokenStore()
    try tokenStore.save(
      SpotifyProviderTokens(accessToken: "access", refreshToken: "refresh")
    )
    let model = AppSessionModel(
      authenticator: authenticator,
      tokenStore: tokenStore,
      accountDeleter: deletionService,
      initialState: .signedIn
    )

    let task = Task { await model.deleteAccount() }
    while model.state == .signedIn {
      await Task.yield()
    }

    XCTAssertEqual(model.state, .deletingAccount)
    await task.value
    XCTAssertEqual(model.state, .signedOut)
    XCTAssertNil(tokenStore.tokens)
    let deletionCallCount = await deletionService.callCount
    let clearLocalSessionCallCount = await authenticator.clearLocalSessionCallCount
    XCTAssertEqual(deletionCallCount, 1)
    XCTAssertEqual(clearLocalSessionCallCount, 1)
  }

  func testDeleteFailureKeepsSessionAndShowsActionableError() async throws {
    let authenticator = FakeSpotifyAuthenticator()
    let deletionService = FakeAccountDeletionService(error: FakeDeletionError.failed)
    let tokenStore = InMemorySpotifyTokenStore()
    let tokens = SpotifyProviderTokens(accessToken: "access", refreshToken: "refresh")
    try tokenStore.save(tokens)
    let model = AppSessionModel(
      authenticator: authenticator,
      tokenStore: tokenStore,
      accountDeleter: deletionService,
      initialState: .signedIn
    )

    await model.deleteAccount()

    XCTAssertEqual(model.state, .signedIn)
    XCTAssertEqual(model.accountDeletionError, "Please try again. Your account was not deleted.")
    XCTAssertEqual(tokenStore.tokens, tokens)
    let clearLocalSessionCallCount = await authenticator.clearLocalSessionCallCount
    XCTAssertEqual(clearLocalSessionCallCount, 0)
  }
}

private actor FakeSpotifyAuthenticator: SpotifyAuthenticating {
  var signOutCallCount = 0
  var clearLocalSessionCallCount = 0

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

  func clearLocalSession() async throws {
    clearLocalSessionCallCount += 1
  }
}

private actor FakeAccountDeletionService: AccountDeleting {
  private(set) var callCount = 0
  private let delay: Duration
  private let error: Error?

  init(delay: Duration = .zero, error: Error? = nil) {
    self.delay = delay
    self.error = error
  }

  func deleteAccount() async throws {
    callCount += 1
    try await Task.sleep(for: delay)
    if let error { throw error }
  }
}

private enum FakeDeletionError: LocalizedError {
  case failed

  var errorDescription: String? {
    "Please try again. Your account was not deleted."
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
