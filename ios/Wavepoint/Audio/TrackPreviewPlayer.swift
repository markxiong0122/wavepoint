import AVFoundation
import Foundation
import Observation

enum TrackPreviewState: Equatable, Sendable {
  case unavailable
  case ready
  case connecting
  case playing
  case paused
}

enum TrackPlaybackSource: Equatable, Sendable {
  case unavailable
  case directPreview
  case spotifyRemote
}

@MainActor
protocol TrackPreviewPlaybackEngine: AnyObject {
  func play(url: URL)
  func pause()
  func resume()
  func stop()
}

@MainActor
protocol SpotifyRemotePlaying: AnyObject {
  func play(uri: String) async throws
  func pause() async throws
  func resume() async throws
}

@MainActor
final class AVPlayerPreviewEngine: TrackPreviewPlaybackEngine {
  private var player: AVPlayer?

  func play(url: URL) {
    let player = AVPlayer(url: url)
    self.player = player
    player.play()
  }

  func pause() {
    player?.pause()
  }

  func resume() {
    player?.play()
  }

  func stop() {
    player?.pause()
    player?.seek(to: .zero)
    player = nil
  }
}

@MainActor
@Observable
final class TrackPreviewPlayer {
  private(set) var state: TrackPreviewState = .unavailable
  private(set) var source: TrackPlaybackSource = .unavailable
  private(set) var errorMessage: String?

  private let engine: any TrackPreviewPlaybackEngine
  private let remote: (any SpotifyRemotePlaying)?
  private let segmentSleep: @Sendable (Duration) async -> Void
  private var previewURL: URL?
  private var spotifyURI: String?
  private var stopTask: Task<Void, Never>?

  init(
    engine: any TrackPreviewPlaybackEngine = AVPlayerPreviewEngine(),
    remote: (any SpotifyRemotePlaying)? = nil,
    segmentSleep: @escaping @Sendable (Duration) async -> Void = { duration in
      try? await Task.sleep(for: duration)
    }
  ) {
    self.engine = engine
    self.remote = remote
    self.segmentSleep = segmentSleep
  }

  func prepare(previewURL: URL?, spotifyURI: String?) {
    stopTask?.cancel()
    if self.previewURL != nil {
      engine.stop()
    }
    self.previewURL = previewURL
    self.spotifyURI = spotifyURI
    errorMessage = nil

    if previewURL != nil {
      source = .directPreview
      state = .ready
    } else if remote != nil, spotifyURI?.isEmpty == false {
      source = .spotifyRemote
      state = .ready
    } else {
      source = .unavailable
      state = .unavailable
    }
  }

  func togglePlayback() async {
    errorMessage = nil

    switch state {
    case .ready:
      await startPlayback()
    case .playing:
      stopTask?.cancel()
      await pausePlayback()
    case .paused:
      await resumePlayback()
    case .unavailable, .connecting:
      break
    }
  }

  func finishSegment() async {
    guard source != .unavailable else { return }
    stopTask?.cancel()
    switch source {
    case .directPreview:
      engine.stop()
    case .spotifyRemote:
      try? await remote?.pause()
    case .unavailable:
      break
    }
    state = .ready
  }

  func stop() async {
    stopTask?.cancel()
    guard source != .unavailable else { return }
    switch source {
    case .directPreview:
      engine.stop()
    case .spotifyRemote:
      try? await remote?.pause()
    case .unavailable:
      break
    }
    state = .ready
  }

  private func startPlayback() async {
    do {
      switch source {
      case .directPreview:
        guard let previewURL else { return }
        engine.play(url: previewURL)
      case .spotifyRemote:
        guard let remote, let spotifyURI else { return }
        state = .connecting
        try await remote.play(uri: spotifyURI)
      case .unavailable:
        return
      }
      state = .playing
      scheduleSegmentEnd()
    } catch {
      state = .ready
      errorMessage = "Spotify couldn't play this track. Open it in Spotify instead."
    }
  }

  private func pausePlayback() async {
    do {
      switch source {
      case .directPreview:
        engine.pause()
      case .spotifyRemote:
        try await remote?.pause()
      case .unavailable:
        return
      }
      state = .paused
    } catch {
      state = .ready
      errorMessage = "Spotify couldn't pause this track. Open Spotify to stop playback."
    }
  }

  private func resumePlayback() async {
    do {
      switch source {
      case .directPreview:
        engine.resume()
      case .spotifyRemote:
        try await remote?.resume()
      case .unavailable:
        return
      }
      state = .playing
      scheduleSegmentEnd()
    } catch {
      state = .ready
      errorMessage = "Spotify couldn't resume this track. Open it in Spotify instead."
    }
  }

  private func scheduleSegmentEnd() {
    stopTask?.cancel()
    let segmentSleep = self.segmentSleep
    stopTask = Task { [weak self] in
      await segmentSleep(.seconds(15))
      guard !Task.isCancelled else { return }
      await self?.finishSegment()
    }
  }
}
