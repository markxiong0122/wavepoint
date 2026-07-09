import Foundation
@preconcurrency import SpotifyiOS

@MainActor
final class SpotifySDKAppRemoteClient: NSObject, SpotifyAppRemoteClient {
  private let appRemote: SPTAppRemote
  private var connectionContinuation: CheckedContinuation<Void, Error>?

  init(clientID: String, callbackURL: URL) {
    let configuration = SPTConfiguration(clientID: clientID, redirectURL: callbackURL)
    appRemote = SPTAppRemote(configuration: configuration, logLevel: .error)
    super.init()
    appRemote.delegate = self
  }

  var isConnected: Bool {
    appRemote.isConnected
  }

  func setAccessToken(_ token: String) {
    appRemote.connectionParameters.accessToken = token
  }

  func connect() async throws {
    guard !appRemote.isConnected else { return }
    guard connectionContinuation == nil else {
      throw SpotifySDKAppRemoteClientError.connectionAlreadyPending
    }

    try await withCheckedThrowingContinuation { continuation in
      connectionContinuation = continuation
      appRemote.connect()
    }
  }

  func authorizeAndPlay(uri: String) async -> Bool {
    await withCheckedContinuation { continuation in
      appRemote.authorizeAndPlayURI(uri) { success in
        continuation.resume(returning: success)
      }
    }
  }

  func play(uri: String) async throws {
    try await performPlayerAction { callback in
      appRemote.playerAPI?.play(uri, callback: callback)
    }
  }

  func pause() async throws {
    try await performPlayerAction { callback in
      appRemote.playerAPI?.pause(callback)
    }
  }

  func resume() async throws {
    try await performPlayerAction { callback in
      appRemote.playerAPI?.resume(callback)
    }
  }

  func handleOpenURL(_ url: URL) -> SpotifyAppRemoteCallbackResult {
    guard let parameters = appRemote.authorizationParameters(from: url) else {
      return .unhandled
    }
    if let token = parameters[SPTAppRemoteAccessTokenKey] {
      return .token(token)
    }
    if let message = parameters[SPTAppRemoteErrorDescriptionKey] {
      return .error(message)
    }
    return .unhandled
  }

  private func performPlayerAction(
    _ action: (@escaping SPTAppRemoteCallback) -> Void
  ) async throws {
    guard appRemote.isConnected, appRemote.playerAPI != nil else {
      throw SpotifyAppRemoteServiceError.notConnected
    }

    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      action { _, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }
}

extension SpotifySDKAppRemoteClient: SPTAppRemoteDelegate {
  nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
    Task { @MainActor in
      connectionContinuation?.resume()
      connectionContinuation = nil
    }
  }

  nonisolated func appRemote(
    _ appRemote: SPTAppRemote,
    didFailConnectionAttemptWithError error: (any Error)?
  ) {
    Task { @MainActor in
      connectionContinuation?.resume(
        throwing: error ?? SpotifySDKAppRemoteClientError.connectionFailed
      )
      connectionContinuation = nil
    }
  }

  nonisolated func appRemote(
    _ appRemote: SPTAppRemote,
    didDisconnectWithError error: (any Error)?
  ) {
    Task { @MainActor in
      guard let connectionContinuation else { return }
      connectionContinuation.resume(
        throwing: error ?? SpotifySDKAppRemoteClientError.disconnected
      )
      self.connectionContinuation = nil
    }
  }
}

private enum SpotifySDKAppRemoteClientError: Error {
  case connectionAlreadyPending
  case connectionFailed
  case disconnected
}
