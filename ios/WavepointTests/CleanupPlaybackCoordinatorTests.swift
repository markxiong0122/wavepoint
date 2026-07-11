import Foundation
import XCTest

@testable import Wavepoint

@MainActor
final class CleanupPlaybackCoordinatorTests: XCTestCase {
  func testFirstTrackStartsSpotifyRemoteAndEnablesAutomaticMode() async {
    let remote = RecordingCleanupRemotePlayer()
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)
    let track = spotifyTrack(
      id: "first",
      previewURL: URL(string: "https://audio.example/first.mp3")
    )

    await coordinator.present(track)

    XCTAssertEqual(coordinator.state, .automatic)
    XCTAssertEqual(player.source, .spotifyRemote)
    XCTAssertEqual(player.state, .playing)
    XCTAssertEqual(remote.events, [.play("spotify:track:first")])
    await coordinator.stop()
  }

  func testNextTrackPausesOutgoingTrackBeforeStarting() async {
    let remote = RecordingCleanupRemotePlayer()
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)

    await coordinator.present(spotifyTrack(id: "first"))
    await coordinator.present(spotifyTrack(id: "second"))

    XCTAssertEqual(
      remote.events,
      [.play("spotify:track:first"), .pause, .play("spotify:track:second")]
    )
    XCTAssertEqual(coordinator.state, .automatic)
    await coordinator.stop()
  }

  func testPresentingCurrentPlayingTrackIsANoOp() async {
    let remote = RecordingCleanupRemotePlayer()
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)
    let track = spotifyTrack(id: "same")

    await coordinator.present(track)
    await coordinator.present(track)

    XCTAssertEqual(remote.events, [.play("spotify:track:same")])
    await coordinator.stop()
  }

  func testFailedFirstStartCanContinueWithManualDirectPreview() async {
    let remote = RecordingCleanupRemotePlayer(error: CleanupRemoteTestError.failed)
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)
    let previewURL = URL(string: "https://audio.example/manual.mp3")!
    let track = spotifyTrack(id: "manual", previewURL: previewURL)

    await coordinator.present(track)
    guard case .failed = coordinator.state else {
      return XCTFail("Expected automatic setup failure")
    }
    await coordinator.continueManually(with: track)

    XCTAssertEqual(coordinator.state, .manual)
    XCTAssertEqual(player.source, .directPreview)
    XCTAssertEqual(player.state, .ready)
  }

  func testRetryStartsAutomaticPlaybackAfterInitialFailure() async {
    let remote = RecordingCleanupRemotePlayer(
      error: CleanupRemoteTestError.failed,
      playFailureCount: 1
    )
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)
    let track = spotifyTrack(id: "retry")

    await coordinator.present(track)
    await coordinator.retry(track)

    XCTAssertEqual(coordinator.state, .automatic)
    XCTAssertEqual(remote.events.last, .play("spotify:track:retry"))
    await coordinator.stop()
  }

  func testLaterAutomaticFailureFallsBackToManualPreview() async {
    let remote = RecordingCleanupRemotePlayer(
      error: CleanupRemoteTestError.failed,
      failOnPlayCall: 2
    )
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)
    let secondPreview = URL(string: "https://audio.example/second.mp3")!

    await coordinator.present(spotifyTrack(id: "first"))
    await coordinator.present(spotifyTrack(id: "second", previewURL: secondPreview))

    XCTAssertEqual(coordinator.state, .manual)
    XCTAssertEqual(player.source, .directPreview)
    XCTAssertEqual(player.state, .ready)
  }

  func testNextCardRetriesAutoplayAfterTransientTrackFailure() async {
    let remote = RecordingCleanupRemotePlayer(
      error: CleanupRemoteTestError.failed,
      failOnPlayCall: 2
    )
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)
    let secondPreview = URL(string: "https://audio.example/second.mp3")!
    let thirdPreview = URL(string: "https://audio.example/third.mp3")!

    await coordinator.present(spotifyTrack(id: "first"))
    await coordinator.present(spotifyTrack(id: "second", previewURL: secondPreview))
    await coordinator.present(spotifyTrack(id: "third", previewURL: thirdPreview))

    XCTAssertEqual(coordinator.state, .automatic)
    XCTAssertEqual(player.source, .spotifyRemote)
    XCTAssertEqual(player.state, .playing)
    XCTAssertEqual(
      remote.events,
      [
        .play("spotify:track:first"),
        .pause,
        .play("spotify:track:second"),
        .play("spotify:track:third"),
      ]
    )
    await coordinator.stop()
  }

  func testExplicitManualModePreparesFollowingCardsWithoutAutoplay() async {
    let remote = RecordingCleanupRemotePlayer(error: CleanupRemoteTestError.failed)
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)
    let first = spotifyTrack(
      id: "first",
      previewURL: URL(string: "https://audio.example/first.mp3")!
    )
    let second = spotifyTrack(
      id: "second",
      previewURL: URL(string: "https://audio.example/second.mp3")!
    )

    await coordinator.present(first)
    await coordinator.continueManually(with: first)
    await coordinator.present(second)

    XCTAssertEqual(coordinator.state, .manual)
    XCTAssertEqual(player.source, .directPreview)
    XCTAssertEqual(player.state, .ready)
    XCTAssertEqual(remote.events, [.play("spotify:track:first")])
  }

  func testStoppingThenPresentingSameTrackResumesWithoutDoublePause() async {
    let remote = RecordingCleanupRemotePlayer()
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)
    let track = spotifyTrack(id: "resume")

    await coordinator.present(track)
    await coordinator.stop()
    await coordinator.present(track)

    XCTAssertEqual(
      remote.events,
      [.play("spotify:track:resume"), .pause, .play("spotify:track:resume")]
    )
    await coordinator.stop()
  }

  func testStoppingInvalidatesPendingFirstStart() async {
    let remote = ControlledCleanupRemotePlayer()
    let player = TrackPreviewPlayer(
      engine: RecordingCleanupPreviewEngine(),
      remote: remote,
      segmentSleep: { duration in try? await Task.sleep(for: duration) }
    )
    let coordinator = CleanupPlaybackCoordinator(player: player)

    let startTask = Task { @MainActor in
      await coordinator.present(spotifyTrack(id: "pending"))
    }
    await remote.waitUntilPlayStarts()
    await coordinator.stop()
    remote.finishPlay()
    await startTask.value

    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertEqual(player.state, .ready)
  }

  private func spotifyTrack(id: String, previewURL: URL? = nil) -> LibraryTrack {
    LibraryTrack(
      id: id,
      provider: .spotify,
      playbackID: "spotify:track:\(id)",
      commitID: "spotify:track:\(id)",
      title: "Track \(id)",
      artistNames: ["Artist"],
      artworkURL: nil,
      previewURL: previewURL,
      destinationURL: URL(string: "https://open.spotify.com/track/\(id)")!,
      durationMilliseconds: 180_000,
      addedAt: Date(timeIntervalSince1970: 0)
    )
  }
}

@MainActor
private final class RecordingCleanupPreviewEngine: TrackPreviewPlaybackEngine {
  func play(url: URL) {}
  func pause() {}
  func resume() {}
  func stop() {}
}

@MainActor
private final class RecordingCleanupRemotePlayer: RemoteTrackPlaying {
  let provider = MusicProvider.spotify
  enum Event: Equatable {
    case play(String)
    case pause
    case resume
  }

  private(set) var events: [Event] = []
  private let error: Error?
  private var playFailuresRemaining: Int
  private let failOnPlayCall: Int?
  private var playCallCount = 0

  init(
    error: Error? = nil,
    playFailureCount: Int? = nil,
    failOnPlayCall: Int? = nil
  ) {
    self.error = error
    playFailuresRemaining = playFailureCount ?? (error == nil ? 0 : .max)
    self.failOnPlayCall = failOnPlayCall
  }

  func play(trackID: String) async throws {
    events.append(.play(trackID))
    playCallCount += 1
    if let error, failOnPlayCall == playCallCount {
      throw error
    }
    if let error, failOnPlayCall == nil, playFailuresRemaining > 0 {
      playFailuresRemaining -= 1
      throw error
    }
  }

  func pause() async throws {
    events.append(.pause)
  }

  func resume() async throws {
    events.append(.resume)
  }
}

private enum CleanupRemoteTestError: Error {
  case failed
}

@MainActor
private final class ControlledCleanupRemotePlayer: RemoteTrackPlaying {
  let provider = MusicProvider.spotify
  private var playContinuation: CheckedContinuation<Void, Error>?
  private var startContinuation: CheckedContinuation<Void, Never>?
  private var didStart = false

  func play(trackID: String) async throws {
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
