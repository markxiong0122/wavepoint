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
