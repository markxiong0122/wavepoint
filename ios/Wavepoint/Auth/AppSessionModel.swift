import Foundation
import Observation

enum AppSessionState: Equatable, Sendable {
  case restoring
  case signedOut
  case authorizing
  case signedIn
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

  init(
    authenticator: any SpotifyAuthenticating,
    tokenStore: any SpotifyTokenStoring,
    accountDeleter: any AccountDeleting,
    initialState: AppSessionState = .restoring
  ) {
    self.authenticator = authenticator
    self.tokenStore = tokenStore
    self.accountDeleter = accountDeleter
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
        state = .signedIn
      } else if try tokenStore.load() != nil {
        state = .signedIn
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
      state = .signedIn
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
}
