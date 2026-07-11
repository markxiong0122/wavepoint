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
  private let analytics: any AnalyticsCapturing
  private let crashReporting: any CrashReporting

  init(
    authenticator: any SpotifyAuthenticating,
    tokenStore: any SpotifyTokenStoring,
    accountDeleter: any AccountDeleting,
    eligibilityChecker: any SpotifyAccountEligibilityChecking,
    analytics: any AnalyticsCapturing = NoOpAnalytics(),
    crashReporting: any CrashReporting = NoOpCrashReporting(),
    initialState: AppSessionState = .restoring
  ) {
    self.authenticator = authenticator
    self.tokenStore = tokenStore
    self.accountDeleter = accountDeleter
    self.eligibilityChecker = eligibilityChecker
    self.analytics = analytics
    self.crashReporting = crashReporting
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
    analytics.capture(.providerConnectionStarted(.spotify))
    state = .authorizing

    do {
      let session = try await authenticator.signIn()
      guard let providerTokens = session.providerTokens else {
        analytics.capture(.providerConnectionFailed(.spotify, .authorization))
        crashReporting.record(.authorization)
        state = .failed(
          "Spotify did not return an access token. Please try connecting again."
        )
        return
      }

      try tokenStore.save(providerTokens)
      await verifyEligibility()
    } catch {
      analytics.capture(.providerConnectionFailed(.spotify, .authorization))
      crashReporting.record(.authorization)
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
      crashReporting.record(.unknown)
      accountDeletionError = error.localizedDescription
      state = .signedIn
      return
    }

    try? await authenticator.clearLocalSession()
    try? tokenStore.delete()
    analytics.capture(.accountDeleted)
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
        analytics.capture(.providerConnectionSucceeded(.spotify))
      case .free:
        try? await authenticator.clearLocalSession()
        try? tokenStore.delete()
        state = .spotifyPremiumRequired
        analytics.capture(.providerConnectionFailed(.spotify, .eligibility))
      case .unverifiable:
        state = .spotifyEligibilityUnavailable
        analytics.capture(.providerConnectionFailed(.spotify, .eligibility))
      }
    } catch SpotifyWebAPIError.accountEligibilityForbidden,
      SpotifyWebAPIError.authorizationExpired
    {
      state = .spotifyReconnectRequired
      analytics.capture(.providerConnectionFailed(.spotify, .authorization))
      crashReporting.record(.authorization)
    } catch {
      state = .spotifyEligibilityUnavailable
      analytics.capture(.providerConnectionFailed(.spotify, .eligibility))
      crashReporting.record(.eligibility)
    }
  }
}
