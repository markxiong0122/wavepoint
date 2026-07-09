import Foundation

struct SpotifyAuthSession: Equatable, Sendable {
  let providerTokens: SpotifyProviderTokens?
}

protocol SpotifyAuthenticating: Sendable {
  func restoreSession() async throws -> SpotifyAuthSession?
  func signIn() async throws -> SpotifyAuthSession
  func signOut() async throws
}
