import Foundation

struct AppleMusicPlaylistRecord: Equatable, Sendable {
  let id: String
  let destinationURL: URL
  let songIDs: [String]
}

enum AppleMusicPlaylistClientError: LocalizedError, Equatable {
  case notEditable
  case playlistNotFound
  case unavailableSongs([String])

  var errorDescription: String? {
    switch self {
    case .notEditable:
      "The saved Dumpster playlist can no longer be edited."
    case .playlistNotFound:
      "The saved Dumpster playlist could not be found."
    case .unavailableSongs:
      "One or more songs are no longer available in the Apple Music library."
    }
  }
}

@MainActor
protocol AppleMusicPlaylistClient: AnyObject {
  func fetchPlaylist(id: String) async throws -> AppleMusicPlaylistRecord?
  func createPlaylist(name: String, songIDs: [String]) async throws -> AppleMusicPlaylistRecord
  func appendSongs(ids: [String], to playlistID: String) async throws
    -> AppleMusicPlaylistRecord
}

@MainActor
final class AppleMusicDumpsterService {
  static let playlistName = "Wavepoint Dumpster 🗑️"

  private let client: any AppleMusicPlaylistClient
  private let store: any DumpsterPlaylistStoring

  init(client: any AppleMusicPlaylistClient, store: any DumpsterPlaylistStoring) {
    self.client = client
    self.store = store
  }

  func commit(songIDs: [String]) async throws -> CleanupCommitResult {
    let stagedIDs = stableUnique(songIDs)
    guard !stagedIDs.isEmpty else { return .noChanges }

    guard let playlistID = store.playlistID else {
      return try await createReplacement(songIDs: stagedIDs)
    }

    guard let existing = try await client.fetchPlaylist(id: playlistID) else {
      return try await createReplacement(songIDs: stagedIDs)
    }

    let originalSet = Set(existing.songIDs)
    let missingIDs = stagedIDs.filter { !originalSet.contains($0) }
    guard !missingIDs.isEmpty else {
      return .dumpster(updatedCount: 0, destinationURL: existing.destinationURL)
    }

    do {
      let updated = try await client.appendSongs(ids: missingIDs, to: existing.id)
      return .dumpster(updatedCount: missingIDs.count, destinationURL: updated.destinationURL)
    } catch AppleMusicPlaylistClientError.notEditable {
      return try await createReplacement(songIDs: stagedIDs)
    } catch AppleMusicPlaylistClientError.playlistNotFound {
      return try await createReplacement(songIDs: stagedIDs)
    } catch {
      return try await reconcileAmbiguousWrite(
        playlistID: existing.id,
        stagedIDs: stagedIDs,
        originalSet: originalSet
      )
    }
  }

  private func createReplacement(songIDs: [String]) async throws -> CleanupCommitResult {
    let created = try await client.createPlaylist(
      name: Self.playlistName,
      songIDs: songIDs
    )
    store.playlistID = created.id
    return .dumpster(updatedCount: songIDs.count, destinationURL: created.destinationURL)
  }

  private func reconcileAmbiguousWrite(
    playlistID: String,
    stagedIDs: [String],
    originalSet: Set<String>
  ) async throws -> CleanupCommitResult {
    guard let refreshed = try await client.fetchPlaylist(id: playlistID) else {
      return try await createReplacement(songIDs: stagedIDs)
    }

    let refreshedSet = Set(refreshed.songIDs)
    let stillMissing = stagedIDs.filter { !refreshedSet.contains($0) }
    let newlyAddedCount = stagedIDs.filter { !originalSet.contains($0) }.count

    guard !stillMissing.isEmpty else {
      return .dumpster(
        updatedCount: newlyAddedCount,
        destinationURL: refreshed.destinationURL
      )
    }

    do {
      let updated = try await client.appendSongs(ids: stillMissing, to: refreshed.id)
      return .dumpster(
        updatedCount: newlyAddedCount,
        destinationURL: updated.destinationURL
      )
    } catch AppleMusicPlaylistClientError.notEditable {
      return try await createReplacement(songIDs: stagedIDs)
    } catch AppleMusicPlaylistClientError.playlistNotFound {
      return try await createReplacement(songIDs: stagedIDs)
    }
  }

  private func stableUnique(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    return ids.filter { seen.insert($0).inserted }
  }
}
