import MusicKit

struct MusicKitLibraryClient: AppleMusicLibraryClient {
  private let songStore: MusicKitSongStore

  init(songStore: MusicKitSongStore = .shared) {
    self.songStore = songStore
  }

  func fetchLibraryPage(offset: Int, limit: Int) async throws -> AppleMusicSongPage {
    var request = MusicLibraryRequest<Song>()
    request.offset = offset
    request.limit = limit
    let response = try await request.response()
    let songs = Array(response.items)
    await songStore.store(songs)
    return AppleMusicSongPage(
      songs: songs.map(Self.record(from:)),
      hasNextPage: response.items.hasNextBatch
    )
  }

  func fetchRecentlyPlayedSongIDs(limit: Int) async throws -> Set<String> {
    var request = MusicRecentlyPlayedRequest<Song>()
    request.limit = limit
    let response = try await request.response()
    return Set(response.items.map { $0.id.rawValue })
  }

  private static func record(from song: Song) -> AppleMusicSongRecord {
    AppleMusicSongRecord(
      id: song.id.rawValue,
      title: song.title,
      artistName: song.artistName,
      artworkURL: song.artwork?.url(width: 640, height: 640),
      previewURL: song.previewAssets?.first?.url,
      destinationURL: song.url,
      duration: song.duration ?? 0,
      libraryAddedDate: song.libraryAddedDate,
      lastPlayedDate: song.lastPlayedDate
    )
  }
}
