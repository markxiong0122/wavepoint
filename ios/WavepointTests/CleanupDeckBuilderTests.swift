import XCTest
@testable import Wavepoint

final class CleanupDeckBuilderTests: XCTestCase {
  func testRanksOutsideRecentRotationThenOldestWithStableTies() {
    let oldest = track(id: "old", addedAt: date("2018-01-01T00:00:00Z"))
    let tiedB = track(id: "b", addedAt: date("2020-01-01T00:00:00Z"))
    let tiedA = track(id: "a", addedAt: date("2020-01-01T00:00:00Z"))
    let recent = track(id: "recent", addedAt: date("2010-01-01T00:00:00Z"))

    let deck = CleanupDeckBuilder().build(
      from: [recent, tiedB, oldest, tiedA],
      recentTrackIDs: ["recent"]
    )

    XCTAssertEqual(deck.map(\.id), ["old", "a", "b", "recent"])
  }

  func testCapsADeckAtFiftySongs() {
    let tracks = (0..<75).map {
      track(id: String(format: "%03d", $0), addedAt: Date(timeIntervalSince1970: 0))
    }

    let deck = CleanupDeckBuilder().build(from: tracks, recentTrackIDs: [])

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
