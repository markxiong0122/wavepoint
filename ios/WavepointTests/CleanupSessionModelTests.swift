import Foundation
import XCTest

@testable import Wavepoint

@MainActor
final class CleanupSessionModelTests: XCTestCase {
  func testLoadBuildsRankedDeckAndStartsDeciding() async {
    let old = track(id: "old", addedAt: Date(timeIntervalSince1970: 100))
    let recent = track(id: "recent", addedAt: Date(timeIntervalSince1970: 0))
    let service = FakeCleanupLibraryService(tracks: [recent, old], recentIDs: ["recent"])
    let model = CleanupSessionModel(service: service)

    await model.load()

    XCTAssertEqual(model.state, .deciding)
    XCTAssertTrue(["old", "recent"].contains(model.currentTrack?.id))
    XCTAssertEqual(model.totalCount, 2)
  }

  func testKeepRemoveAndUndoRestoreThePreviousCard() async {
    let first = track(id: "first", addedAt: Date(timeIntervalSince1970: 0))
    let second = track(id: "second", addedAt: Date(timeIntervalSince1970: 1))
    let model = CleanupSessionModel(
      service: FakeCleanupLibraryService(tracks: [first, second])
    )
    await model.load()
    let firstDisplayedTrack = model.currentTrack

    model.keepCurrentTrack()
    let secondDisplayedTrack = model.currentTrack
    XCTAssertNotEqual(secondDisplayedTrack, firstDisplayedTrack)
    model.removeCurrentTrack()
    XCTAssertEqual(model.state, .reviewing)
    XCTAssertEqual(model.stagedRemovals, [secondDisplayedTrack].compactMap { $0 })

    model.cancelReview()
    model.undo()

    XCTAssertEqual(model.state, .deciding)
    XCTAssertEqual(model.currentTrack, secondDisplayedTrack)
    XCTAssertTrue(model.stagedRemovals.isEmpty)
    XCTAssertEqual(model.completedCount, 1)
  }

  func testFinishEarlyReviewsOnlyStagedRemovals() async {
    let tracks = [
      track(id: "remove", addedAt: Date(timeIntervalSince1970: 0)),
      track(id: "unseen", addedAt: Date(timeIntervalSince1970: 1)),
    ]
    let model = CleanupSessionModel(service: FakeCleanupLibraryService(tracks: tracks))
    await model.load()
    let displayedTrack = model.currentTrack

    model.removeCurrentTrack()
    model.beginReview()

    XCTAssertEqual(model.state, .reviewing)
    XCTAssertEqual(model.stagedRemovals, [displayedTrack].compactMap { $0 })
  }

  func testConfirmCommitsStagedURIsAndCompletes() async {
    let service = FakeCleanupLibraryService(
      tracks: [track(id: "remove", addedAt: Date(timeIntervalSince1970: 0))]
    )
    let model = CleanupSessionModel(service: service)
    await model.load()
    model.removeCurrentTrack()

    await model.confirmRemovals()

    XCTAssertEqual(model.state, .complete(.init(decisionCount: 1, removedCount: 1)))
    let removedURIs = await service.removedURIs
    XCTAssertEqual(removedURIs, ["spotify:track:remove"])
  }

  func testEmptyLibraryCompletesWithoutDecisions() async {
    let model = CleanupSessionModel(service: FakeCleanupLibraryService(tracks: []))

    await model.load()

    XCTAssertEqual(model.state, .complete(.init(decisionCount: 0, removedCount: 0)))
  }

  func testLoadFailureShowsRetryableError() async {
    let model = CleanupSessionModel(
      service: FakeCleanupLibraryService(tracks: [], loadError: SpotifyWebAPIError.rateLimited)
    )

    await model.load()

    guard case .failed(let message) = model.state else {
      return XCTFail("Expected failed state")
    }
    XCTAssertTrue(message.contains("too many requests"))
  }

  private func track(id: String, addedAt: Date) -> LibraryTrack {
    LibraryTrack(
      id: id,
      provider: .spotify,
      playbackID: "spotify:track:\(id)",
      commitID: "spotify:track:\(id)",
      title: "Song \(id)",
      artistNames: ["Artist"],
      artworkURL: nil,
      previewURL: nil,
      destinationURL: URL(string: "https://open.spotify.com/track/\(id)")!,
      durationMilliseconds: 180_000,
      addedAt: addedAt
    )
  }
}

private actor FakeCleanupLibraryService: CleanupLibraryServing {
  private let tracks: [LibraryTrack]
  private let recentIDs: Set<String>
  private let loadError: (any Error)?
  private(set) var removedURIs: [String] = []

  init(
    tracks: [LibraryTrack],
    recentIDs: Set<String> = [],
    loadError: (any Error)? = nil
  ) {
    self.tracks = tracks
    self.recentIDs = recentIDs
    self.loadError = loadError
  }

  func fetchLibraryTracks() async throws -> [LibraryTrack] {
    if let loadError { throw loadError }
    return tracks
  }

  func fetchRecentlyPlayedTrackIDs() async throws -> Set<String> {
    recentIDs
  }

  func commit(trackIDs: [String]) async throws -> CleanupCommitResult {
    removedURIs.append(contentsOf: trackIDs)
    return CleanupCommitResult(committedCount: trackIDs.count)
  }
}
