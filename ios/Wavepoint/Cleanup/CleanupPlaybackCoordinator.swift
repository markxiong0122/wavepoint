import Foundation
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

  init(player: TrackPreviewPlayer) {
    self.player = player
  }

  func present(_ track: SpotifyTrack) async {
    guard currentTrackID != track.id || player.state != .playing else { return }
    if state == .manual {
      await continueManually(with: track)
      return
    }
    currentTrackID = track.id
    if !hasStartedDeck {
      state = .starting
    }
    await player.stop()
    player.prepare(previewURL: nil, spotifyURI: track.uri)
    await player.togglePlayback()

    if player.state == .playing {
      hasStartedDeck = true
      state = .automatic
    } else if hasStartedDeck {
      player.prepare(previewURL: track.previewURL, spotifyURI: track.uri)
      state = .manual
    } else {
      state = .failed(
        player.errorMessage ?? "Spotify couldn't start autoplay. Please try again."
      )
    }
  }

  func continueManually(with track: SpotifyTrack) async {
    await player.stop()
    currentTrackID = track.id
    player.prepare(previewURL: track.previewURL, spotifyURI: track.uri)
    hasStartedDeck = true
    state = .manual
  }

  func retry(_ track: SpotifyTrack) async {
    currentTrackID = nil
    await present(track)
  }

  func stop() async {
    await player.stop()
  }
}
