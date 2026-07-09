import AVFoundation
import Foundation
import Observation

enum TrackPreviewState: Equatable, Sendable {
  case unavailable
  case ready
  case playing
  case paused
}

@MainActor
protocol TrackPreviewPlaybackEngine: AnyObject {
  func play(url: URL)
  func pause()
  func resume()
  func stop()
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

  private let engine: any TrackPreviewPlaybackEngine
  private var currentURL: URL?
  private var stopTask: Task<Void, Never>?

  init(engine: any TrackPreviewPlaybackEngine = AVPlayerPreviewEngine()) {
    self.engine = engine
  }

  func prepare(url: URL?) {
    stopTask?.cancel()
    if currentURL != nil {
      engine.stop()
    }
    currentURL = url
    state = url == nil ? .unavailable : .ready
  }

  func togglePlayback() {
    switch state {
    case .ready:
      guard let currentURL else { return }
      engine.play(url: currentURL)
      state = .playing
      scheduleSegmentEnd()
    case .playing:
      stopTask?.cancel()
      engine.pause()
      state = .paused
    case .paused:
      engine.resume()
      state = .playing
      scheduleSegmentEnd()
    case .unavailable:
      break
    }
  }

  func finishSegment() {
    guard currentURL != nil else { return }
    stopTask?.cancel()
    engine.stop()
    state = .ready
  }

  func stop() {
    stopTask?.cancel()
    guard currentURL != nil else { return }
    engine.stop()
    state = .ready
  }

  private func scheduleSegmentEnd() {
    stopTask?.cancel()
    stopTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(15))
      guard !Task.isCancelled else { return }
      self?.finishSegment()
    }
  }
}
