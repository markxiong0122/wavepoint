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
  case authorizationTimedOut

  var errorDescription: String? {
    switch self {
    case .spotifyNotInstalled:
      "Install the Spotify app to play this track."
    case .notConnected:
      "Wavepoint is not connected to Spotify."
    case .authorizationFailed(let message):
      message
    case .authorizationTimedOut:
      "Spotify didn't finish connecting. Please try again."
    }
  }
}

@MainActor
final class SpotifyAppRemoteService: RemoteTrackPlaying {
  let provider = MusicProvider.spotify
  private let client: any SpotifyAppRemoteClient
  private let accessToken: @MainActor () async throws -> String
  private let authorizationTimeoutSleep: @MainActor (Duration) async -> Void
  private var authorizationContinuation: CheckedContinuation<Void, Error>?
  private var authorizationTimeoutTask: Task<Void, Never>?

  init(
    client: any SpotifyAppRemoteClient,
    accessToken: @escaping @MainActor () async throws -> String,
    authorizationTimeoutSleep: @escaping @MainActor (Duration) async -> Void = { duration in
      try? await Task.sleep(for: duration)
    }
  ) {
    self.client = client
    self.accessToken = accessToken
    self.authorizationTimeoutSleep = authorizationTimeoutSleep
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
      try await requestAuthorizationAndPlay(uri: uri)
    }

    try await client.play(uri: uri)
  }

  func play(trackID: String) async throws {
    try await play(uri: trackID)
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
      do {
        try await client.connect()
        finishAuthorization(with: .success(()))
      } catch {
        finishAuthorization(with: .failure(error))
        throw error
      }
      return true
    case .error(let message):
      let error = SpotifyAppRemoteServiceError.authorizationFailed(message)
      finishAuthorization(with: .failure(error))
      throw error
    case .unhandled:
      return false
    }
  }

  private func requestAuthorizationAndPlay(uri: String) async throws {
    try await withCheckedThrowingContinuation { continuation in
      authorizationContinuation = continuation
      authorizationTimeoutTask = Task { @MainActor [weak self] in
        guard let self else { return }
        await authorizationTimeoutSleep(.seconds(15))
        guard !Task.isCancelled else { return }
        finishAuthorization(
          with: .failure(SpotifyAppRemoteServiceError.authorizationTimedOut)
        )
      }
      Task { @MainActor in
        guard await client.authorizeAndPlay(uri: uri) else {
          finishAuthorization(with: .failure(SpotifyAppRemoteServiceError.spotifyNotInstalled))
          return
        }
      }
    }
  }

  private func finishAuthorization(with result: Result<Void, Error>) {
    guard let authorizationContinuation else { return }
    self.authorizationContinuation = nil
    authorizationTimeoutTask?.cancel()
    authorizationTimeoutTask = nil
    authorizationContinuation.resume(with: result)
  }
}
