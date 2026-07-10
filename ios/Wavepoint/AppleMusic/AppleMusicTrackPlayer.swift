import Foundation
@preconcurrency import MusicKit

enum AppleMusicTrackPlayerError: LocalizedError, Equatable {
  case unavailable

  var errorDescription: String? {
    "This song is unavailable for Apple Music playback. Open it in Music instead."
  }
}

@MainActor
protocol AppleMusicPlayerClient: AnyObject {
  func play(songID: String) async throws
  func pause()
  func resume() async throws
}

@MainActor
final class AppleMusicTrackPlayer: RemoteTrackPlaying {
  let provider = MusicProvider.appleMusic
  private let client: any AppleMusicPlayerClient

  init(client: any AppleMusicPlayerClient = SystemAppleMusicPlayerClient()) {
    self.client = client
  }

  func play(trackID: String) async throws {
    try await client.play(songID: trackID)
  }

  func pause() async throws {
    client.pause()
  }

  func resume() async throws {
    try await client.resume()
  }
}

actor MusicKitSongStore {
  static let shared = MusicKitSongStore()

  private var songsByID: [String: Song] = [:]

  func store(_ songs: [Song]) {
    for song in songs {
      songsByID[song.id.rawValue] = song
    }
  }

  func song(id: String) -> Song? {
    songsByID[id]
  }

  func songs(ids: [String]) -> [Song]? {
    var songs: [Song] = []
    songs.reserveCapacity(ids.count)

    for id in ids {
      guard let song = songsByID[id] else { return nil }
      songs.append(song)
    }

    return songs
  }

  func availableIDs(from ids: [String]) -> Set<String> {
    Set(ids.filter { songsByID[$0] != nil })
  }
}

@MainActor
final class SystemAppleMusicPlayerClient: AppleMusicPlayerClient {
  private let player: ApplicationMusicPlayer
  private let songStore: MusicKitSongStore

  init(
    player: ApplicationMusicPlayer = .shared,
    songStore: MusicKitSongStore = .shared
  ) {
    self.player = player
    self.songStore = songStore
  }

  func play(songID: String) async throws {
    guard let song = await songStore.song(id: songID) else {
      throw AppleMusicTrackPlayerError.unavailable
    }

    player.stop()
    player.queue = ApplicationMusicPlayer.Queue(for: [song])
    try await player.prepareToPlay()
    let duration = song.duration ?? 0
    player.playbackTime = min(30, max(0, duration - 15))
    try await player.play()
  }

  func pause() {
    player.pause()
  }

  func resume() async throws {
    try await player.play()
  }
}
