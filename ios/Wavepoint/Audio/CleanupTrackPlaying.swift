import Foundation

@MainActor
protocol RemoteTrackPlaying: AnyObject {
  var provider: MusicProvider { get }
  func play(trackID: String) async throws
  func pause() async throws
  func resume() async throws
}
