import XCTest

@testable import Wavepoint

@MainActor
final class AppleMusicTrackPlayerTests: XCTestCase {
  func testAppleMusicRemotePlaysAndPausesAtSegmentEnd() async {
    let client = RecordingAppleMusicPlayerClient()
    let remote = AppleMusicTrackPlayer(client: client)
    let player = TrackPreviewPlayer(
      engine: AppleRecordingPreviewEngine(),
      remote: remote,
      segmentSleep: { _ in }
    )
    player.prepare(previewURL: nil, playbackID: "apple-song")

    await player.togglePlayback()
    await Task.yield()
    await Task.yield()

    XCTAssertEqual(player.source, .appleMusic)
    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(client.events, [.play("apple-song"), .pause])
  }

  func testAppleMusicPlayerForwardsPauseAndResume() async throws {
    let client = RecordingAppleMusicPlayerClient()
    let remote = AppleMusicTrackPlayer(client: client)

    try await remote.play(trackID: "apple-song")
    try await remote.pause()
    try await remote.resume()

    XCTAssertEqual(client.events, [.play("apple-song"), .pause, .resume])
    XCTAssertEqual(remote.provider, .appleMusic)
  }

  func testAppleMusicUnavailableErrorRemainsActionable() async {
    let remote = AppleMusicTrackPlayer(
      client: RecordingAppleMusicPlayerClient(error: AppleMusicTrackPlayerError.unavailable)
    )
    let player = TrackPreviewPlayer(engine: AppleRecordingPreviewEngine(), remote: remote)
    player.prepare(previewURL: nil, playbackID: "missing")

    await player.togglePlayback()

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(
      player.errorMessage,
      "This song is unavailable for Apple Music playback. Open it in Music instead."
    )
  }
}

@MainActor
private final class RecordingAppleMusicPlayerClient: AppleMusicPlayerClient {
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

  func play(songID: String) async throws {
    events.append(.play(songID))
    if let error { throw error }
  }

  func pause() {
    events.append(.pause)
  }

  func resume() async throws {
    events.append(.resume)
    if let error { throw error }
  }
}

@MainActor
private final class AppleRecordingPreviewEngine: TrackPreviewPlaybackEngine {
  func play(url: URL) {}
  func pause() {}
  func resume() {}
  func stop() {}
}
