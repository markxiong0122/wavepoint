import Foundation
import OSLog
@preconcurrency import SpotifyiOS

@MainActor
final class SpotifySDKAppRemoteClient: NSObject, SpotifyAppRemoteClient {
  private let logger = Logger(subsystem: "ai.mapier.swipe", category: "SpotifyAppRemote")
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

    logger.debug("Starting App Remote connection")
    diagnose("Starting App Remote connection")
    try await withCheckedThrowingContinuation { continuation in
      connectionContinuation = continuation
      appRemote.connect()
    }
  }

  func authorizeAndPlay(uri: String) async -> Bool {
    let result = await withCheckedContinuation { continuation in
      appRemote.authorizeAndPlayURI(uri) { success in
        continuation.resume(returning: success)
      }
    }
    logger.debug("Spotify authorization handoff completed: \(result, privacy: .public)")
    diagnose("Spotify authorization handoff completed: \(result)")
    return result
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
      logger.debug("Ignored non-App-Remote callback")
      diagnose("Ignored non-App-Remote callback")
      return .unhandled
    }
    if let token = parameters[SPTAppRemoteAccessTokenKey] {
      logger.debug("Received App Remote access token callback")
      diagnose("Received App Remote access token callback")
      return .token(token)
    }
    if let message = parameters[SPTAppRemoteErrorDescriptionKey] {
      logger.error("Received App Remote authorization error: \(message, privacy: .public)")
      diagnose("Received App Remote authorization error: \(message)")
      return .error(message)
    }
    logger.error("Received App Remote callback without token or error")
    diagnose("Received App Remote callback without token or error")
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

  private func diagnose(_ message: String) {
    #if DEBUG
      print("[Wavepoint SpotifyAppRemote] \(message)")
    #endif
  }
}

extension SpotifySDKAppRemoteClient: SPTAppRemoteDelegate {
  nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
    Task { @MainActor in
      logger.debug("App Remote connection established")
      diagnose("App Remote connection established")
      connectionContinuation?.resume()
      connectionContinuation = nil
    }
  }

  nonisolated func appRemote(
    _ appRemote: SPTAppRemote,
    didFailConnectionAttemptWithError error: (any Error)?
  ) {
    Task { @MainActor in
      let connectionError = error as NSError?
      logger.error(
        "App Remote connection failed domain=\(connectionError?.domain ?? "unknown", privacy: .public) code=\(connectionError?.code ?? -1, privacy: .public)"
      )
      diagnose(
        "App Remote connection failed domain=\(connectionError?.domain ?? "unknown") code=\(connectionError?.code ?? -1)"
      )
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
      let disconnectionError = error as NSError?
      logger.error(
        "App Remote disconnected domain=\(disconnectionError?.domain ?? "unknown", privacy: .public) code=\(disconnectionError?.code ?? -1, privacy: .public)"
      )
      diagnose(
        "App Remote disconnected domain=\(disconnectionError?.domain ?? "unknown") code=\(disconnectionError?.code ?? -1)"
      )
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
