import Observation

enum CleanupPlaybackState: Equatable, Sendable {
  case idle
  case starting
  case automatic
  case manual
  case failed(String)
}

@MainActor
@Observable
final class CleanupPlaybackCoordinator {
  private(set) var state: CleanupPlaybackState = .idle
  let player: TrackPreviewPlayer
  private var currentTrackID: String?
  private var hasStartedDeck = false
  private var prefersManualPlayback = false
  private var presentationGeneration = 0

  init(player: TrackPreviewPlayer) {
    self.player = player
  }

  func present(_ track: LibraryTrack) async {
    guard currentTrackID != track.id || player.state != .playing else { return }
    presentationGeneration += 1
    let generation = presentationGeneration
    if prefersManualPlayback {
      await prepareManually(track, generation: generation)
      return
    }
    currentTrackID = track.id
    if !hasStartedDeck {
      state = .starting
    }
    if playerNeedsStop {
      await player.stop()
      guard generation == presentationGeneration else { return }
    }
    player.prepare(previewURL: nil, playbackID: track.playbackID)
    await player.togglePlayback()
    guard generation == presentationGeneration else { return }

    if player.state == .playing {
      hasStartedDeck = true
      state = .automatic
    } else if hasStartedDeck {
      player.prepare(previewURL: track.previewURL, playbackID: track.playbackID)
      state = .manual
    } else {
      state = .failed(
        player.errorMessage ?? "Spotify couldn't start autoplay. Please try again."
      )
    }
  }

  func continueManually(with track: LibraryTrack) async {
    prefersManualPlayback = true
    presentationGeneration += 1
    await prepareManually(track, generation: presentationGeneration)
  }

  func retry(_ track: LibraryTrack) async {
    currentTrackID = nil
    await present(track)
  }

  func stop() async {
    presentationGeneration += 1
    await player.stop()
    if !hasStartedDeck {
      state = .idle
    }
  }

  private func prepareManually(
    _ track: LibraryTrack,
    generation: Int
  ) async {
    if playerNeedsStop {
      await player.stop()
      guard generation == presentationGeneration else { return }
    }
    currentTrackID = track.id
    player.prepare(previewURL: track.previewURL, playbackID: track.playbackID)
    hasStartedDeck = true
    state = .manual
  }

  private var playerNeedsStop: Bool {
    player.state != .ready && player.state != .unavailable
  }
}
