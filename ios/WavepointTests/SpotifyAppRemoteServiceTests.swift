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

  func testConnectionFailureWakesSpotifyOnlyForExplicitPlay() async {
    let client = RecordingAppRemoteClient(
      isConnected: false,
      connectError: RemoteClientTestError.connectionFailed,
      callbackResult: .error("Test completed.")
    )
    let service = SpotifyAppRemoteService(client: client) { "provider-token" }
    let callback = URL(string: "ai.mapier.swipe://spotify-app-remote-callback#error=test")!

    XCTAssertEqual(client.events, [])

    let playTask = Task { @MainActor in
      try? await service.play(uri: "spotify:track:wake")
    }
    for _ in 0..<10 where !client.events.contains(.authorizeAndPlay("spotify:track:wake")) {
      await Task.yield()
    }

    XCTAssertEqual(
      client.events,
      [
        .setAccessToken("provider-token"),
        .connect,
        .authorizeAndPlay("spotify:track:wake"),
      ]
    )
    _ = try? await service.handleOpenURL(callback)
    await playTask.value
  }

  func testAuthorizationHandoffWaitsForSuccessfulCallbackBeforeCompleting() async throws {
    let callback = URL(string: "ai.mapier.swipe://spotify-app-remote-callback#access_token=fresh")!
    let client = RecordingAppRemoteClient(
      isConnected: false,
      connectError: RemoteClientTestError.connectionFailed,
      callbackResult: .token("callback-token")
    )
    let service = SpotifyAppRemoteService(client: client) { "provider-token" }
    var didComplete = false

    let playTask = Task { @MainActor in
      try await service.play(uri: "spotify:track:wake")
      didComplete = true
    }
    for _ in 0..<10 where !client.events.contains(.authorizeAndPlay("spotify:track:wake")) {
      await Task.yield()
    }

    XCTAssertFalse(didComplete)
    let handled = try await service.handleOpenURL(callback)
    XCTAssertTrue(handled)
    try await playTask.value
    XCTAssertTrue(didComplete)
  }

  func testAuthorizationErrorCompletesPendingPlayWithSameError() async {
    let callback = URL(string: "ai.mapier.swipe://spotify-app-remote-callback#error=denied")!
    let client = RecordingAppRemoteClient(
      isConnected: false,
      connectError: RemoteClientTestError.connectionFailed,
      callbackResult: .error("Spotify denied access.")
    )
    let service = SpotifyAppRemoteService(client: client) { "provider-token" }
    let playCompleted = expectation(description: "Pending play completed")
    var playError: SpotifyAppRemoteServiceError?

    Task { @MainActor in
      do {
        try await service.play(uri: "spotify:track:denied")
      } catch {
        playError = error as? SpotifyAppRemoteServiceError
      }
      playCompleted.fulfill()
    }
    for _ in 0..<10 where !client.events.contains(.authorizeAndPlay("spotify:track:denied")) {
      await Task.yield()
    }

    do {
      _ = try await service.handleOpenURL(callback)
      XCTFail("Expected callback authorization error")
    } catch {
      XCTAssertEqual(
        error as? SpotifyAppRemoteServiceError,
        .authorizationFailed("Spotify denied access.")
      )
    }
    await fulfillment(of: [playCompleted], timeout: 1)
    XCTAssertEqual(playError, .authorizationFailed("Spotify denied access."))
  }

  func testCallbackConnectionFailureCompletesPendingPlay() async {
    let callback = URL(string: "ai.mapier.swipe://spotify-app-remote-callback#access_token=fresh")!
    let client = RecordingAppRemoteClient(
      isConnected: false,
      connectError: RemoteClientTestError.connectionFailed,
      connectFailureCount: 2,
      callbackResult: .token("callback-token")
    )
    let service = SpotifyAppRemoteService(client: client) { "provider-token" }
    let playCompleted = expectation(description: "Pending play completed")
    var playFailed = false

    Task { @MainActor in
      do {
        try await service.play(uri: "spotify:track:connection-failure")
      } catch {
        playFailed = true
      }
      playCompleted.fulfill()
    }
    for _ in 0..<10
    where !client.events.contains(.authorizeAndPlay("spotify:track:connection-failure")) {
      await Task.yield()
    }

    do {
      _ = try await service.handleOpenURL(callback)
      XCTFail("Expected callback connection error")
    } catch {
      XCTAssertTrue(error is RemoteClientTestError)
    }
    await fulfillment(of: [playCompleted], timeout: 1)
    XCTAssertTrue(playFailed)
  }

  func testMissingAuthorizationCallbackTimesOutPendingPlay() async {
    let sleeper = ControlledAuthorizationSleep()
    let client = RecordingAppRemoteClient(
      isConnected: false,
      connectError: RemoteClientTestError.connectionFailed
    )
    let service = SpotifyAppRemoteService(
      client: client,
      accessToken: { "provider-token" },
      authorizationTimeoutSleep: sleeper.sleep
    )
    let playCompleted = expectation(description: "Pending play completed")
    var playError: SpotifyAppRemoteServiceError?

    Task { @MainActor in
      do {
        try await service.play(uri: "spotify:track:no-callback")
      } catch {
        playError = error as? SpotifyAppRemoteServiceError
      }
      playCompleted.fulfill()
    }
    for _ in 0..<10 where !client.events.contains(.authorizeAndPlay("spotify:track:no-callback")) {
      await Task.yield()
    }
    sleeper.finish()

    await fulfillment(of: [playCompleted], timeout: 1)
    XCTAssertEqual(playError, .authorizationTimedOut)
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
  private var connectFailuresRemaining: Int
  private let canAuthorize: Bool
  private let callbackResult: SpotifyAppRemoteCallbackResult

  init(
    isConnected: Bool,
    connectError: Error? = nil,
    connectFailureCount: Int? = nil,
    canAuthorize: Bool = true,
    callbackResult: SpotifyAppRemoteCallbackResult = .unhandled
  ) {
    self.isConnected = isConnected
    self.connectError = connectError
    connectFailuresRemaining = connectFailureCount ?? (connectError == nil ? 0 : 1)
    self.canAuthorize = canAuthorize
    self.callbackResult = callbackResult
  }

  func setAccessToken(_ token: String) {
    events.append(.setAccessToken(token))
  }

  func connect() async throws {
    events.append(.connect)
    if let connectError, connectFailuresRemaining > 0 {
      connectFailuresRemaining -= 1
      throw connectError
    }
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

@MainActor
private final class ControlledAuthorizationSleep {
  private var continuation: CheckedContinuation<Void, Never>?
  private var isFinished = false

  func sleep(_: Duration) async {
    guard !isFinished else { return }
    await withCheckedContinuation { continuation = $0 }
  }

  func finish() {
    isFinished = true
    continuation?.resume()
    continuation = nil
  }
}
