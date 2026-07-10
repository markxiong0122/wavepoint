import AuthenticationServices
import Foundation
import Supabase

struct SpotifyAuthorizationRequest: Equatable, Sendable {
  let provider: Provider
  let callbackURL: URL
  let scopes: String

  var callbackScheme: String {
    callbackURL.scheme ?? ""
  }

  init(callbackURL: URL) throws {
    guard callbackURL.scheme != nil else {
      throw SpotifyAuthorizationRequestError.missingCallbackScheme
    }

    provider = .spotify
    self.callbackURL = callbackURL
    scopes = [
      "user-read-email",
      "user-read-private",
      "user-library-read",
      "user-library-modify",
      "user-read-recently-played",
      "app-remote-control",
    ].joined(separator: " ")
  }
}

enum SpotifyAuthorizationRequestError: Error, Equatable {
  case missingCallbackScheme
}

struct SupabaseSpotifyAuthenticator: SpotifyAuthenticating {
  private let client: SupabaseClient
  private let request: SpotifyAuthorizationRequest

  init(client: SupabaseClient, callbackURL: URL) throws {
    self.client = client
    request = try SpotifyAuthorizationRequest(callbackURL: callbackURL)
  }

  static func makeClient(configuration: AppConfiguration) -> SupabaseClient {
    SupabaseClient(
      supabaseURL: configuration.supabaseURL,
      supabaseKey: configuration.supabasePublishableKey,
      options: SupabaseClientOptions(
        auth: .init(
          redirectToURL: configuration.callbackURL,
          flowType: .pkce
        )
      )
    )
  }

  func restoreSession() async throws -> SpotifyAuthSession? {
    guard client.auth.currentSession != nil else { return nil }
    return SpotifyAuthSession(session: try await client.auth.session)
  }

  func signIn() async throws -> SpotifyAuthSession {
    let session = try await client.auth.signInWithOAuth(
      provider: request.provider,
      redirectTo: request.callbackURL,
      scopes: request.scopes
    ) { session in
      session.prefersEphemeralWebBrowserSession = false
    }
    return SpotifyAuthSession(session: session)
  }

  func signOut() async throws {
    try await client.auth.signOut()
  }

  func clearLocalSession() async throws {
    try await client.auth.signOut(scope: .local)
  }
}

extension SpotifyAuthSession {
  fileprivate init(session: Session) {
    let tokens = session.providerToken.map {
      SpotifyProviderTokens(
        accessToken: $0,
        refreshToken: session.providerRefreshToken
      )
    }
    self.init(providerTokens: tokens)
  }
}
