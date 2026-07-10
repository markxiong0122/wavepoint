import Foundation

enum CleanupCommitResult: Equatable, Sendable {
  case noChanges
  case removed(count: Int)
  case dumpster(updatedCount: Int, destinationURL: URL)

  var committedCount: Int {
    switch self {
    case .noChanges:
      0
    case .removed(let count):
      count
    case .dumpster(let updatedCount, _):
      updatedCount
    }
  }

  var destinationURL: URL? {
    guard case .dumpster(_, let destinationURL) = self else { return nil }
    return destinationURL
  }
}

enum CleanupCommitError: LocalizedError, Equatable, Sendable {
  case partial(committedCount: Int, remainingCount: Int)

  var errorDescription: String? {
    switch self {
    case .partial(let committedCount, let remainingCount):
      "Committed \(committedCount) songs, but \(remainingCount) still need to be retried."
    }
  }
}

protocol CleanupLibraryServing: Sendable {
  var provider: MusicProvider { get }
  func fetchLibraryTracks() async throws -> [LibraryTrack]
  func fetchRecentlyPlayedTrackIDs() async throws -> Set<String>
  func commit(trackIDs: [String]) async throws -> CleanupCommitResult
}
