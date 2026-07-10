import Foundation

struct CleanupDeckBuilder: Sendable {
  let maximumTrackCount: Int
  let referenceDate: Date

  init(
    maximumTrackCount: Int = 50,
    referenceDate: Date = .now
  ) {
    self.maximumTrackCount = maximumTrackCount
    self.referenceDate = referenceDate
  }

  func build(
    from tracks: [LibraryTrack],
    recentTrackIDs: Set<String>,
    seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)
  ) -> [LibraryTrack] {
    var generator = SplitMix64(seed: seed)

    return
      tracks
      .map { track in
        let randomValue = max(
          Double.random(in: 0..<1, using: &generator),
          Double.leastNonzeroMagnitude
        )
        let weight = selectionWeight(
          for: track,
          recentTrackIDs: recentTrackIDs
        )
        return (track: track, priority: log(randomValue) / weight)
      }
      .sorted { lhs, rhs in
        if lhs.priority != rhs.priority {
          return lhs.priority > rhs.priority
        }
        return lhs.track.id < rhs.track.id
      }
      .prefix(maximumTrackCount)
      .map(\.track)
  }

  func selectionWeight(
    for track: LibraryTrack,
    recentTrackIDs: Set<String>
  ) -> Double {
    let ageInYears = track.addedAt.map {
      max(0, referenceDate.timeIntervalSince($0) / (365.25 * 24 * 60 * 60))
    } ?? 0
    let ageWeight = 1 + min(ageInYears, 12)
    let rotationWeight = recentTrackIDs.contains(track.id) ? 0.2 : 1
    return ageWeight * rotationWeight
  }
}

private struct SplitMix64: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
}
