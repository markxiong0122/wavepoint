import Foundation

struct AppleMusicSongRecord: Equatable, Sendable {
  let id: String
  let title: String
  let artistName: String
  let artworkURL: URL?
  let previewURL: URL?
  let destinationURL: URL?
  let duration: TimeInterval
  let libraryAddedDate: Date?
  let lastPlayedDate: Date?
}

struct AppleMusicSongPage: Equatable, Sendable {
  let songs: [AppleMusicSongRecord]
  let hasNextPage: Bool
}

protocol AppleMusicLibraryClient: Sendable {
  func fetchLibraryPage(offset: Int, limit: Int) async throws -> AppleMusicSongPage
  func fetchRecentlyPlayedSongIDs(limit: Int) async throws -> Set<String>
}

actor AppleMusicLibraryService: CleanupLibraryServing {
  nonisolated let provider = MusicProvider.appleMusic

  private let client: any AppleMusicLibraryClient
  private let pageSize: Int
  private let referenceDate: Date
  private let recentWindow: TimeInterval
  private let commitHandler: @Sendable ([String]) async throws -> CleanupCommitResult
  private var activeLoadTask: Task<[AppleMusicSongRecord], Error>?

  init(
    client: any AppleMusicLibraryClient,
    pageSize: Int = 100,
    referenceDate: Date = .now,
    recentWindow: TimeInterval = 30 * 24 * 60 * 60,
    commit: @escaping @Sendable ([String]) async throws -> CleanupCommitResult
  ) {
    self.client = client
    self.pageSize = max(1, pageSize)
    self.referenceDate = referenceDate
    self.recentWindow = recentWindow
    commitHandler = commit
  }

  func fetchLibraryTracks() async throws -> [LibraryTrack] {
    try await loadSongs().map { song in
      LibraryTrack(
        id: song.id,
        provider: .appleMusic,
        playbackID: song.id,
        commitID: song.id,
        title: song.title,
        artistNames: [song.artistName],
        artworkURL: song.artworkURL,
        previewURL: song.previewURL,
        destinationURL: song.destinationURL,
        durationMilliseconds: Int((max(0, song.duration) * 1_000).rounded()),
        addedAt: song.libraryAddedDate
      )
    }
  }

  func fetchRecentlyPlayedTrackIDs() async throws -> Set<String> {
    async let requestedIDs = client.fetchRecentlyPlayedSongIDs(limit: 50)
    let cutoff = referenceDate.addingTimeInterval(-recentWindow)
    let libraryIDs = try await Set<String>(
      loadSongs().compactMap { song in
        guard let lastPlayedDate = song.lastPlayedDate, lastPlayedDate >= cutoff else {
          return nil
        }
        return song.id
      }
    )
    return try await libraryIDs.union(requestedIDs)
  }

  func commit(trackIDs: [String]) async throws -> CleanupCommitResult {
    try await commitHandler(trackIDs)
  }

  private func loadSongs() async throws -> [AppleMusicSongRecord] {
    if let activeLoadTask {
      return try await activeLoadTask.value
    }

    let client = self.client
    let pageSize = self.pageSize
    let task = Task {
      var songs: [AppleMusicSongRecord] = []
      var offset = 0
      while true {
        let page = try await client.fetchLibraryPage(offset: offset, limit: pageSize)
        songs.append(contentsOf: page.songs)
        guard page.hasNextPage, !page.songs.isEmpty else { break }
        offset += page.songs.count
      }
      return songs
    }
    activeLoadTask = task

    do {
      let songs = try await task.value
      activeLoadTask = nil
      return songs
    } catch {
      activeLoadTask = nil
      throw error
    }
  }
}
