import Foundation
import Observation

enum AppSessionState: Equatable, Sendable {
  case restoring
  case signedOut
  case authorizing
  case signedIn
  case spotifyPremiumRequired
  case spotifyReconnectRequired
  case spotifyEligibilityUnavailable
  case deletingAccount
  case failed(String)
}

@MainActor
@Observable
final class AppSessionModel {
  private(set) var state: AppSessionState
  private(set) var accountDeletionError: String?

  private let authenticator: any SpotifyAuthenticating
  private let tokenStore: any SpotifyTokenStoring
  private let accountDeleter: any AccountDeleting
  private let eligibilityChecker: any SpotifyAccountEligibilityChecking

  init(
    authenticator: any SpotifyAuthenticating,
    tokenStore: any SpotifyTokenStoring,
    accountDeleter: any AccountDeleting,
    eligibilityChecker: any SpotifyAccountEligibilityChecking,
    initialState: AppSessionState = .restoring
  ) {
    self.authenticator = authenticator
    self.tokenStore = tokenStore
    self.accountDeleter = accountDeleter
    self.eligibilityChecker = eligibilityChecker
    state = initialState
  }

  func restore() async {
    state = .restoring

    do {
      guard let session = try await authenticator.restoreSession() else {
        state = .signedOut
        return
      }

      if let providerTokens = session.providerTokens {
        try tokenStore.save(providerTokens)
        await verifyEligibility()
      } else if try tokenStore.load() != nil {
        await verifyEligibility()
      } else {
        state = .signedOut
      }
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  func signIn() async {
    state = .authorizing

    do {
      let session = try await authenticator.signIn()
      guard let providerTokens = session.providerTokens else {
        state = .failed(
          "Spotify did not return an access token. Please try connecting again."
        )
        return
      }

      try tokenStore.save(providerTokens)
      await verifyEligibility()
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  func signOut() async {
    do {
      try await authenticator.signOut()
      try tokenStore.delete()
      state = .signedOut
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  func retryEligibility() async {
    guard (try? tokenStore.load()) != nil else {
      state = .signedOut
      return
    }
    state = .authorizing
    await verifyEligibility()
  }

  func reconnect() async {
    try? await authenticator.clearLocalSession()
    try? tokenStore.delete()
    await signIn()
  }

  func deleteAccount() async {
    accountDeletionError = nil
    state = .deletingAccount

    do {
      try await accountDeleter.deleteAccount()
    } catch {
      accountDeletionError = error.localizedDescription
      state = .signedIn
      return
    }

    try? await authenticator.clearLocalSession()
    try? tokenStore.delete()
    state = .signedOut
  }

  func dismissAccountDeletionError() {
    accountDeletionError = nil
  }

  private func verifyEligibility() async {
    do {
      switch try await eligibilityChecker.fetchAccountEligibility() {
      case .premium:
        state = .signedIn
      case .free:
        try? await authenticator.clearLocalSession()
        try? tokenStore.delete()
        state = .spotifyPremiumRequired
      case .unverifiable:
        state = .spotifyEligibilityUnavailable
      }
    } catch SpotifyWebAPIError.accountEligibilityForbidden,
      SpotifyWebAPIError.authorizationExpired
    {
      state = .spotifyReconnectRequired
    } catch {
      state = .spotifyEligibilityUnavailable
    }
  }
}
