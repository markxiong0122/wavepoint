import XCTest
@testable import Wavepoint

final class CleanupDeckBuilderTests: XCTestCase {
  func testOlderAndOutsideRotationTracksReceiveHigherSelectionWeights() {
    let now = date("2026-01-01T00:00:00Z")
    let builder = CleanupDeckBuilder(referenceDate: now)
    let old = track(id: "old", addedAt: date("2018-01-01T00:00:00Z"))
    let new = track(id: "new", addedAt: date("2025-12-01T00:00:00Z"))

    let oldWeight = builder.selectionWeight(for: old, recentTrackIDs: [])
    let newWeight = builder.selectionWeight(for: new, recentTrackIDs: [])
    let recentOldWeight = builder.selectionWeight(for: old, recentTrackIDs: ["old"])

    XCTAssertGreaterThan(oldWeight, newWeight)
    XCTAssertLessThan(recentOldWeight, oldWeight)
  }

  func testSeedProducesARepeatableWeightedShuffle() {
    let tracks = (0..<12).map {
      track(
        id: String(format: "%03d", $0),
        addedAt: Date(timeIntervalSince1970: TimeInterval($0 * 1_000))
      )
    }
    let builder = CleanupDeckBuilder(referenceDate: date("2026-01-01T00:00:00Z"))

    let first = builder.build(from: tracks, recentTrackIDs: [], seed: 42)
    let second = builder.build(from: tracks, recentTrackIDs: [], seed: 42)
    let different = builder.build(from: tracks, recentTrackIDs: [], seed: 7)

    XCTAssertEqual(first.map(\.id), second.map(\.id))
    XCTAssertNotEqual(first.map(\.id), different.map(\.id))
    XCTAssertEqual(Set(first.map(\.id)), Set(tracks.map(\.id)))
  }

  func testCapsADeckAtFiftySongs() {
    let tracks = (0..<75).map {
      track(id: String(format: "%03d", $0), addedAt: Date(timeIntervalSince1970: 0))
    }

    let deck = CleanupDeckBuilder().build(from: tracks, recentTrackIDs: [], seed: 1)

    XCTAssertEqual(deck.count, 50)
  }

  private func track(id: String, addedAt: Date) -> SpotifyTrack {
    SpotifyTrack(
      id: id,
      uri: "spotify:track:\(id)",
      name: "Track \(id)",
      artistNames: ["Artist"],
      artworkURL: nil,
      previewURL: nil,
      spotifyURL: URL(string: "https://open.spotify.com/track/\(id)")!,
      durationMilliseconds: 180_000,
      addedAt: addedAt
    )
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}
