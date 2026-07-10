import Foundation
import XCTest

@testable import Wavepoint

final class AppleMusicLibraryServiceTests: XCTestCase {
  func testFetchLibraryTracksLoadsEveryPageAndMapsProviderFields() async throws {
    let first = song(id: "one", title: "First", addedAt: date("2018-01-01T00:00:00Z"))
    let second = song(id: "two", title: "Second", addedAt: nil)
    let third = song(id: "three", title: "Third", addedAt: date("2025-01-01T00:00:00Z"))
    let client = FakeAppleMusicLibraryClient(pages: [
      0: AppleMusicSongPage(songs: [first, second], hasNextPage: true),
      2: AppleMusicSongPage(songs: [third], hasNextPage: false),
    ])
    let service = AppleMusicLibraryService(
      client: client,
      pageSize: 2,
      referenceDate: date("2026-01-01T00:00:00Z"),
      commit: { _ in .noChanges }
    )

    let tracks = try await service.fetchLibraryTracks()

    XCTAssertEqual(tracks.map(\.id), ["one", "two", "three"])
    XCTAssertTrue(tracks.allSatisfy { $0.provider == .appleMusic })
    XCTAssertEqual(tracks.first?.playbackID, "one")
    XCTAssertEqual(tracks.first?.commitID, "one")
    XCTAssertEqual(tracks.first?.title, "First")
    XCTAssertEqual(tracks.first?.artistLine, "Artist")
    XCTAssertEqual(tracks.first?.artworkURL, URL(string: "https://img.example/one.jpg"))
    XCTAssertEqual(tracks.first?.previewURL, URL(string: "https://audio.example/one.m4a"))
    XCTAssertEqual(tracks.first?.destinationURL, URL(string: "music://song/one"))
    XCTAssertEqual(tracks.first?.durationMilliseconds, 181_500)
    XCTAssertNil(tracks[1].addedAt)
    let requestedOffsets = await client.requestedOffsets
    XCTAssertEqual(requestedOffsets, [0, 2])
  }

  func testRecentEvidenceCombinesRecentlyPlayedAndLibraryLastPlayedDate() async throws {
    let now = date("2026-01-31T00:00:00Z")
    let client = FakeAppleMusicLibraryClient(
      pages: [
        0: AppleMusicSongPage(
          songs: [
            song(id: "last-played", lastPlayedAt: date("2026-01-15T00:00:00Z")),
            song(id: "old-play", lastPlayedAt: date("2025-01-01T00:00:00Z")),
          ],
          hasNextPage: false
        )
      ],
      recentIDs: ["recent-request"]
    )
    let service = AppleMusicLibraryService(
      client: client,
      referenceDate: now,
      recentWindow: 30 * 24 * 60 * 60,
      commit: { _ in .noChanges }
    )

    let recentIDs = try await service.fetchRecentlyPlayedTrackIDs()

    XCTAssertEqual(recentIDs, ["last-played", "recent-request"])
  }

  func testCommitForwardsStableAppleSongIDs() async throws {
    let recorder = AppleCommitRecorder()
    let service = AppleMusicLibraryService(
      client: FakeAppleMusicLibraryClient(pages: [:]),
      commit: { ids in
        await recorder.record(ids)
        return .dumpster(
          updatedCount: ids.count,
          destinationURL: URL(string: "music://playlist/dumpster")!
        )
      }
    )

    let result = try await service.commit(trackIDs: ["one", "two"])

    XCTAssertEqual(result.committedCount, 2)
    let recordedIDs = await recorder.ids
    XCTAssertEqual(recordedIDs, ["one", "two"])
  }

  private func song(
    id: String,
    title: String = "Song",
    addedAt: Date? = nil,
    lastPlayedAt: Date? = nil
  ) -> AppleMusicSongRecord {
    AppleMusicSongRecord(
      id: id,
      title: title,
      artistName: "Artist",
      artworkURL: URL(string: "https://img.example/\(id).jpg"),
      previewURL: URL(string: "https://audio.example/\(id).m4a"),
      destinationURL: URL(string: "music://song/\(id)"),
      duration: 181.5,
      libraryAddedDate: addedAt,
      lastPlayedDate: lastPlayedAt
    )
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}

private actor FakeAppleMusicLibraryClient: AppleMusicLibraryClient {
  private let pages: [Int: AppleMusicSongPage]
  private let recentIDs: Set<String>
  private(set) var requestedOffsets: [Int] = []

  init(
    pages: [Int: AppleMusicSongPage],
    recentIDs: Set<String> = []
  ) {
    self.pages = pages
    self.recentIDs = recentIDs
  }

  func fetchLibraryPage(offset: Int, limit: Int) async throws -> AppleMusicSongPage {
    requestedOffsets.append(offset)
    return pages[offset] ?? AppleMusicSongPage(songs: [], hasNextPage: false)
  }

  func fetchRecentlyPlayedSongIDs(limit: Int) async throws -> Set<String> {
    recentIDs
  }
}

private actor AppleCommitRecorder {
  private(set) var ids: [String] = []

  func record(_ ids: [String]) {
    self.ids = ids
  }
}
