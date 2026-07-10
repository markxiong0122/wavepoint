import Foundation

struct CleanupCommitResult: Equatable, Sendable {
  let committedCount: Int
}

protocol CleanupLibraryServing: Sendable {
  func fetchLibraryTracks() async throws -> [LibraryTrack]
  func fetchRecentlyPlayedTrackIDs() async throws -> Set<String>
  func commit(trackIDs: [String]) async throws -> CleanupCommitResult
}
