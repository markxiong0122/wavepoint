import Foundation

enum SpotifyAppRemoteCallbackResult: Equatable {
  case token(String)
  case error(String)
  case unhandled
}

@MainActor
protocol SpotifyAppRemoteClient: AnyObject {
  var isConnected: Bool { get }

  func setAccessToken(_ token: String)
  func connect() async throws
  func authorizeAndPlay(uri: String) async -> Bool
  func play(uri: String) async throws
  func pause() async throws
  func resume() async throws
  func handleOpenURL(_ url: URL) -> SpotifyAppRemoteCallbackResult
}

enum SpotifyAppRemoteServiceError: LocalizedError, Equatable {
  case spotifyNotInstalled
  case notConnected
  case authorizationFailed(String)

  var errorDescription: String? {
    switch self {
    case .spotifyNotInstalled:
      "Install the Spotify app to play this track."
    case .notConnected:
      "Wavepoint is not connected to Spotify."
    case .authorizationFailed(let message):
      message
    }
  }
}

@MainActor
final class SpotifyAppRemoteService: SpotifyRemotePlaying {
  private let client: any SpotifyAppRemoteClient
  private let accessToken: @MainActor () async throws -> String

  init(
    client: any SpotifyAppRemoteClient,
    accessToken: @escaping @MainActor () async throws -> String
  ) {
    self.client = client
    self.accessToken = accessToken
  }

  func play(uri: String) async throws {
    if client.isConnected {
      try await client.play(uri: uri)
      return
    }

    client.setAccessToken(try await accessToken())
    do {
      try await client.connect()
    } catch {
      guard await client.authorizeAndPlay(uri: uri) else {
        throw SpotifyAppRemoteServiceError.spotifyNotInstalled
      }
      return
    }

    try await client.play(uri: uri)
  }

  func pause() async throws {
    guard client.isConnected else {
      throw SpotifyAppRemoteServiceError.notConnected
    }
    try await client.pause()
  }

  func resume() async throws {
    guard client.isConnected else {
      throw SpotifyAppRemoteServiceError.notConnected
    }
    try await client.resume()
  }

  func handleOpenURL(_ url: URL) async throws -> Bool {
    switch client.handleOpenURL(url) {
    case .token(let token):
      client.setAccessToken(token)
      try await client.connect()
      return true
    case .error(let message):
      throw SpotifyAppRemoteServiceError.authorizationFailed(message)
    case .unhandled:
      return false
    }
  }
}
