import Foundation
import XCTest
@testable import Wavepoint

@MainActor
final class TrackPreviewPlayerTests: XCTestCase {
  func testMissingPreviewUsesSpotifyRemoteWhenURIExists() {
    let player = TrackPreviewPlayer(
      engine: RecordingPreviewEngine(),
      remote: RecordingRemotePlayer()
    )

    player.prepare(previewURL: nil, spotifyURI: "spotify:track:missing-preview")

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(player.source, .spotifyRemote)
  }

  func testTrackWithoutPreviewOrURIIsUnavailable() {
    let player = TrackPreviewPlayer(
      engine: RecordingPreviewEngine(),
      remote: RecordingRemotePlayer()
    )

    player.prepare(previewURL: nil, spotifyURI: nil)

    XCTAssertEqual(player.state, .unavailable)
    XCTAssertEqual(player.source, .unavailable)
  }

  func testDirectPreviewWinsWithoutCallingSpotifyRemote() async {
    let engine = RecordingPreviewEngine()
    let remote = RecordingRemotePlayer()
    let player = TrackPreviewPlayer(engine: engine, remote: remote)
    let url = URL(string: "https://audio.example/preview.mp3")!
    player.prepare(previewURL: url, spotifyURI: "spotify:track:has-preview")

    await player.togglePlayback()
    XCTAssertEqual(player.state, .playing)
    await player.togglePlayback()
    XCTAssertEqual(player.state, .paused)
    await player.togglePlayback()
    XCTAssertEqual(player.state, .playing)
    await player.finishSegment()

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(player.source, .directPreview)
    XCTAssertEqual(engine.events, [.play(url), .pause, .resume, .stop])
    XCTAssertEqual(remote.events, [])
  }

  func testRemotePlaybackUsesSpotifyAndPausesAtSegmentEnd() async {
    let remote = RecordingRemotePlayer()
    let player = TrackPreviewPlayer(
      engine: RecordingPreviewEngine(),
      remote: remote,
      segmentSleep: { _ in }
    )
    player.prepare(previewURL: nil, spotifyURI: "spotify:track:remote")

    await player.togglePlayback()
    await Task.yield()
    await Task.yield()

    XCTAssertEqual(remote.events, [.play("spotify:track:remote"), .pause])
    XCTAssertEqual(player.state, .ready)
  }

  func testPreparingAnotherTrackStopsCurrentDirectPlayback() async {
    let engine = RecordingPreviewEngine()
    let player = TrackPreviewPlayer(engine: engine, remote: RecordingRemotePlayer())
    player.prepare(
      previewURL: URL(string: "https://audio.example/one.mp3"),
      spotifyURI: "spotify:track:one"
    )
    await player.togglePlayback()

    player.prepare(
      previewURL: URL(string: "https://audio.example/two.mp3"),
      spotifyURI: "spotify:track:two"
    )

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(engine.events.last, .stop)
  }

  func testRemoteFailureReturnsToReadyWithUsefulError() async {
    let remote = RecordingRemotePlayer(error: RemoteTestError.failed)
    let player = TrackPreviewPlayer(engine: RecordingPreviewEngine(), remote: remote)
    player.prepare(previewURL: nil, spotifyURI: "spotify:track:failure")

    await player.togglePlayback()

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(player.errorMessage, "Spotify couldn't play this track. Open it in Spotify instead.")
  }

  func testRemoteAuthorizationFailureSurfacesItsActionableMessage() async {
    let remote = RecordingRemotePlayer(error: SpotifyAppRemoteServiceError.authorizationTimedOut)
    let player = TrackPreviewPlayer(engine: RecordingPreviewEngine(), remote: remote)
    player.prepare(previewURL: nil, spotifyURI: "spotify:track:timeout")

    await player.togglePlayback()

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(player.errorMessage, "Spotify didn't finish connecting. Please try again.")
  }

  func testPreparingNewTrackInvalidatesPendingRemoteStart() async {
    let remote = ControlledRemotePlayer()
    let player = TrackPreviewPlayer(
      engine: RecordingPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    player.prepare(previewURL: nil, spotifyURI: "spotify:track:a")

    let oldStart = Task { @MainActor in
      await player.togglePlayback()
    }
    await remote.waitUntilPlayStarts()
    player.prepare(previewURL: nil, spotifyURI: "spotify:track:b")
    remote.finishPlay()
    await oldStart.value

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(player.source, .spotifyRemote)
  }
}

@MainActor
private final class RecordingPreviewEngine: TrackPreviewPlaybackEngine {
  enum Event: Equatable {
    case play(URL)
    case pause
    case resume
    case stop
  }

  private(set) var events: [Event] = []

  func play(url: URL) { events.append(.play(url)) }
  func pause() { events.append(.pause) }
  func resume() { events.append(.resume) }
  func stop() { events.append(.stop) }
}

@MainActor
private final class RecordingRemotePlayer: SpotifyRemotePlaying {
  enum Event: Equatable {
    case play(String)
    case pause
    case resume
  }

  private(set) var events: [Event] = []
  private let error: Error?

  init(error: Error? = nil) {
    self.error = error
  }

  func play(uri: String) async throws {
    events.append(.play(uri))
    if let error { throw error }
  }

  func pause() async throws {
    events.append(.pause)
    if let error { throw error }
  }

  func resume() async throws {
    events.append(.resume)
    if let error { throw error }
  }
}

private enum RemoteTestError: Error {
  case failed
}

@MainActor
private final class ControlledRemotePlayer: SpotifyRemotePlaying {
  private var playContinuation: CheckedContinuation<Void, Error>?
  private var startContinuation: CheckedContinuation<Void, Never>?
  private var didStart = false

  func play(uri: String) async throws {
    try await withCheckedThrowingContinuation { continuation in
      playContinuation = continuation
      didStart = true
      startContinuation?.resume()
      startContinuation = nil
    }
  }

  func pause() async throws {}
  func resume() async throws {}

  func waitUntilPlayStarts() async {
    guard !didStart else { return }
    await withCheckedContinuation { startContinuation = $0 }
  }

  func finishPlay() {
    playContinuation?.resume()
    playContinuation = nil
  }
}
