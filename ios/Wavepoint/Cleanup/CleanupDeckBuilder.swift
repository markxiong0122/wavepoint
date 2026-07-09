import Foundation

struct CleanupDeckBuilder: Sendable {
  let maximumTrackCount: Int

  init(maximumTrackCount: Int = 50) {
    self.maximumTrackCount = maximumTrackCount
  }

  func build(
    from tracks: [SpotifyTrack],
    recentTrackIDs: Set<String>
  ) -> [SpotifyTrack] {
    tracks
      .sorted { lhs, rhs in
        let lhsIsRecent = recentTrackIDs.contains(lhs.id)
        let rhsIsRecent = recentTrackIDs.contains(rhs.id)
        if lhsIsRecent != rhsIsRecent {
          return !lhsIsRecent
        }
        if lhs.addedAt != rhs.addedAt {
          return lhs.addedAt < rhs.addedAt
        }
        return lhs.id < rhs.id
      }
      .prefix(maximumTrackCount)
      .map { $0 }
  }
}
