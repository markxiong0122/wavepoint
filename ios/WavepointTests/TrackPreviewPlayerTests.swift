import Foundation
import XCTest
@testable import Wavepoint

@MainActor
final class TrackPreviewPlayerTests: XCTestCase {
  func testMissingURLIsUnavailable() {
    let player = TrackPreviewPlayer(engine: RecordingPreviewEngine())

    player.prepare(url: nil)

    XCTAssertEqual(player.state, .unavailable)
  }

  func testPlayPauseResumeAndStopDriveTheEngine() {
    let engine = RecordingPreviewEngine()
    let player = TrackPreviewPlayer(engine: engine)
    let url = URL(string: "https://audio.example/preview.mp3")!
    player.prepare(url: url)

    player.togglePlayback()
    XCTAssertEqual(player.state, .playing)
    player.togglePlayback()
    XCTAssertEqual(player.state, .paused)
    player.togglePlayback()
    XCTAssertEqual(player.state, .playing)
    player.finishSegment()

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(engine.events, [.play(url), .pause, .resume, .stop])
  }

  func testPreparingAnotherTrackStopsCurrentPlayback() {
    let engine = RecordingPreviewEngine()
    let player = TrackPreviewPlayer(engine: engine)
    player.prepare(url: URL(string: "https://audio.example/one.mp3"))
    player.togglePlayback()

    player.prepare(url: URL(string: "https://audio.example/two.mp3"))

    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(engine.events.last, .stop)
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
