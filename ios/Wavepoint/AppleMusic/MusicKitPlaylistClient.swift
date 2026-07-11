import Foundation
@preconcurrency import MusicKit

@MainActor
final class MusicKitPlaylistClient: AppleMusicPlaylistClient {
  private static let description =
    "Songs staged for cleanup by Wavepoint. Remove them from your library in Apple Music, then clear this playlist."

  private let library: MusicLibrary
  private let songStore: MusicKitSongStore

  init(
    library: MusicLibrary = .shared,
    songStore: MusicKitSongStore = .shared
  ) {
    self.library = library
    self.songStore = songStore
  }

  func fetchPlaylist(id: String) async throws -> AppleMusicPlaylistRecord? {
    guard let playlist = try await fetchPlaylistValue(id: id) else { return nil }
    let detailed = try await playlist.with(.entries)
    let songIDs: [String] = detailed.entries?.compactMap { entry -> String? in
      guard let item = entry.item else { return nil }
      guard case .song(let song) = item else { return nil }
      return song.id.rawValue
    } ?? []

    return record(for: detailed, songIDs: songIDs)
  }

  func createPlaylist(name: String, songIDs: [String]) async throws
    -> AppleMusicPlaylistRecord
  {
    let songs = try await resolveSongs(ids: songIDs)

    do {
      let playlist = try await library.createPlaylist(
        name: name,
        description: Self.description,
        items: songs
      )
      return record(for: playlist, songIDs: songIDs)
    } catch {
      throw mapLibraryError(error)
    }
  }

  func appendSongs(ids songIDs: [String], to playlistID: String) async throws
    -> AppleMusicPlaylistRecord
  {
    guard var playlist = try await fetchPlaylistValue(id: playlistID) else {
      throw AppleMusicPlaylistClientError.playlistNotFound
    }
    let songs = try await resolveSongs(ids: songIDs)

    do {
      for song in songs {
        playlist = try await library.add(song, to: playlist)
      }
      return record(for: playlist, songIDs: songIDs)
    } catch {
      throw mapLibraryError(error)
    }
  }

  private func fetchPlaylistValue(id: String) async throws -> Playlist? {
    var request = MusicLibraryRequest<Playlist>()
    request.limit = 1
    request.filter(matching: \.id, equalTo: MusicItemID(id))
    return try await request.response().items.first
  }

  private func resolveSongs(ids: [String]) async throws -> [Song] {
    guard let songs = await songStore.songs(ids: ids) else {
      let availableIDs = await songStore.availableIDs(from: ids)
      throw AppleMusicPlaylistClientError.unavailableSongs(
        ids.filter { !availableIDs.contains($0) }
      )
    }
    return songs
  }

  private func record(for playlist: Playlist, songIDs: [String]) -> AppleMusicPlaylistRecord {
    AppleMusicPlaylistRecord(
      id: playlist.id.rawValue,
      destinationURL: playlist.url ?? fallbackURL(for: playlist.id.rawValue),
      songIDs: songIDs
    )
  }

  private func fallbackURL(for id: String) -> URL {
    var components = URLComponents()
    components.scheme = "music"
    components.host = "playlist"
    components.path = "/\(id)"
    return components.url!
  }

  private func mapLibraryError(_ error: Error) -> Error {
    guard let libraryError = error as? MusicLibrary.Error else { return error }

    return switch libraryError {
    case .playlistNotInLibrary:
      AppleMusicPlaylistClientError.playlistNotFound
    case .editPlaylistFailed:
      AppleMusicPlaylistClientError.notEditable
    default:
      error
    }
  }
}
