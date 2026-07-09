import Foundation
import XCTest
@testable import Wavepoint

@MainActor
final class SpotifyAppRemoteServiceTests: XCTestCase {
  func testConnectedPlaybackDoesNotFetchTokenOrReconnect() async throws {
    let client = RecordingAppRemoteClient(isConnected: true)
    let tokenProvider = RecordingAccessTokenProvider()
    let service = SpotifyAppRemoteService(client: client, accessToken: tokenProvider.token)

    try await service.play(uri: "spotify:track:connected")

    XCTAssertEqual(client.events, [.play("spotify:track:connected")])
    XCTAssertEqual(tokenProvider.callCount, 0)
  }

  func testDisconnectedPlaybackConnectsWithProviderTokenBeforePlaying() async throws {
    let client = RecordingAppRemoteClient(isConnected: false)
    let tokenProvider = RecordingAccessTokenProvider(token: "provider-token")
    let service = SpotifyAppRemoteService(client: client, accessToken: tokenProvider.token)

    try await service.play(uri: "spotify:track:connect")

    XCTAssertEqual(
      client.events,
      [.setAccessToken("provider-token"), .connect, .play("spotify:track:connect")]
    )
    XCTAssertEqual(tokenProvider.callCount, 1)
  }

  func testConnectionFailureWakesSpotifyOnlyForExplicitPlay() async throws {
    let client = RecordingAppRemoteClient(
      isConnected: false,
      connectError: RemoteClientTestError.connectionFailed
    )
    let service = SpotifyAppRemoteService(client: client) { "provider-token" }

    XCTAssertEqual(client.events, [])

    try await service.play(uri: "spotify:track:wake")

    XCTAssertEqual(
      client.events,
      [
        .setAccessToken("provider-token"),
        .connect,
        .authorizeAndPlay("spotify:track:wake"),
      ]
    )
  }

  func testCallbackStoresReturnedTokenAndReconnects() async throws {
    let callback = URL(string: "ai.mapier.swipe://spotify-app-remote-callback#access_token=fresh")!
    let client = RecordingAppRemoteClient(
      isConnected: false,
      callbackResult: .token("callback-token")
    )
    let service = SpotifyAppRemoteService(client: client) { "provider-token" }

    let handled = try await service.handleOpenURL(callback)

    XCTAssertTrue(handled)
    XCTAssertEqual(client.events, [.handleURL(callback), .setAccessToken("callback-token"), .connect])
  }

  func testUnrelatedCallbackIsIgnored() async throws {
    let callback = URL(string: "ai.mapier.swipe://login-callback")!
    let client = RecordingAppRemoteClient(isConnected: false, callbackResult: .unhandled)
    let service = SpotifyAppRemoteService(client: client) { "provider-token" }

    let handled = try await service.handleOpenURL(callback)

    XCTAssertFalse(handled)
    XCTAssertEqual(client.events, [.handleURL(callback)])
  }

  func testMissingSpotifyAppReturnsUsefulError() async {
    let client = RecordingAppRemoteClient(
      isConnected: false,
      connectError: RemoteClientTestError.connectionFailed,
      canAuthorize: false
    )
    let service = SpotifyAppRemoteService(client: client) { "provider-token" }

    do {
      try await service.play(uri: "spotify:track:missing-app")
      XCTFail("Expected Spotify not installed error")
    } catch {
      XCTAssertEqual(error as? SpotifyAppRemoteServiceError, .spotifyNotInstalled)
    }
  }
}

@MainActor
private final class RecordingAppRemoteClient: SpotifyAppRemoteClient {
  enum Event: Equatable {
    case setAccessToken(String)
    case connect
    case authorizeAndPlay(String)
    case play(String)
    case pause
    case resume
    case handleURL(URL)
  }

  var isConnected: Bool
  private(set) var events: [Event] = []

  private let connectError: Error?
  private let canAuthorize: Bool
  private let callbackResult: SpotifyAppRemoteCallbackResult

  init(
    isConnected: Bool,
    connectError: Error? = nil,
    canAuthorize: Bool = true,
    callbackResult: SpotifyAppRemoteCallbackResult = .unhandled
  ) {
    self.isConnected = isConnected
    self.connectError = connectError
    self.canAuthorize = canAuthorize
    self.callbackResult = callbackResult
  }

  func setAccessToken(_ token: String) {
    events.append(.setAccessToken(token))
  }

  func connect() async throws {
    events.append(.connect)
    if let connectError { throw connectError }
    isConnected = true
  }

  func authorizeAndPlay(uri: String) async -> Bool {
    events.append(.authorizeAndPlay(uri))
    return canAuthorize
  }

  func play(uri: String) async throws {
    events.append(.play(uri))
  }

  func pause() async throws {
    events.append(.pause)
  }

  func resume() async throws {
    events.append(.resume)
  }

  func handleOpenURL(_ url: URL) -> SpotifyAppRemoteCallbackResult {
    events.append(.handleURL(url))
    return callbackResult
  }
}

@MainActor
private final class RecordingAccessTokenProvider {
  private(set) var callCount = 0
  private let value: String

  init(token: String = "unused") {
    value = token
  }

  func token() async throws -> String {
    callCount += 1
    return value
  }
}

private enum RemoteClientTestError: Error {
  case connectionFailed
}
