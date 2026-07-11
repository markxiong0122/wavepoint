import Foundation
import XCTest

@testable import Wavepoint

@MainActor
final class CleanupSessionModelTests: XCTestCase {
  func testCapturesTheClosedCleanupFunnelWithoutSongData() async {
    let analytics = RecordingAnalytics()
    let model = CleanupSessionModel(
      service: FakeCleanupLibraryService(tracks: [track(id: "one", addedAt: .distantPast)]),
      analytics: analytics
    )

    await model.load()
    model.removeCurrentTrack()
    await model.confirmRemovals()

    XCTAssertEqual(
      analytics.events,
      [
        .cleanupDeckLoaded(.spotify),
        .firstDecisionCompleted(.spotify),
        .reviewOpened(.spotify),
        .cleanupSessionCompleted(.spotify),
      ]
    )
  }

  func testReportsOnlyCoarseLoadFailureCategory() async {
    let crashes = RecordingCrashReporting()
    let model = CleanupSessionModel(
      service: FakeCleanupLibraryService(
        tracks: [],
        loadError: SpotifyWebAPIError.rateLimited
      ),
      crashReporting: crashes
    )

    await model.load()

    XCTAssertEqual(crashes.categories, [.libraryLoad])
  }

  func testProviderChangeConfirmationIsRequiredOnlyAfterAUserDecision() async {
    let service = FakeCleanupLibraryService(
      tracks: [track(id: "one", addedAt: .distantPast)]
    )
    let model = CleanupSessionModel(service: service)

    await model.load()
    XCTAssertFalse(model.requiresProviderChangeConfirmation)

    model.keepCurrentTrack()
    XCTAssertTrue(model.requiresProviderChangeConfirmation)
  }
  func testLoadBuildsRankedDeckAndStartsDeciding() async {
    let old = track(id: "old", addedAt: Date(timeIntervalSince1970: 100))
    let recent = track(id: "recent", addedAt: Date(timeIntervalSince1970: 0))
    let service = FakeCleanupLibraryService(tracks: [recent, old])
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

    XCTAssertEqual(
      model.state,
      .complete(
        .init(
          provider: .spotify,
          decisionCount: 1,
          result: .removed(count: 1)
        )
      )
    )
    let removedURIs = await service.removedURIs
    XCTAssertEqual(removedURIs, ["spotify:track:remove"])
  }

  func testAppleCommitCompletesWithTruthfulDumpsterResult() async {
    let destination = URL(string: "music://playlist/dumpster")!
    let service = FakeCleanupLibraryService(
      provider: .appleMusic,
      tracks: [track(id: "toss", addedAt: Date(timeIntervalSince1970: 0))],
      commitResult: .dumpster(updatedCount: 1, destinationURL: destination)
    )
    let model = CleanupSessionModel(service: service)
    await model.load()
    model.removeCurrentTrack()

    await model.confirmRemovals()

    XCTAssertEqual(
      model.state,
      .complete(
        .init(
          provider: .appleMusic,
          decisionCount: 1,
          result: .dumpster(updatedCount: 1, destinationURL: destination)
        )
      )
    )
  }

  func testPartialSpotifyCommitKeepsOnlyUnconfirmedTracksStaged() async {
    let service = FakeCleanupLibraryService(
      tracks: [
        track(id: "one", addedAt: Date(timeIntervalSince1970: 0)),
        track(id: "two", addedAt: Date(timeIntervalSince1970: 1)),
      ],
      commitError: CleanupCommitError.partial(
        committedCount: 1,
        remainingCount: 1
      )
    )
    let model = CleanupSessionModel(service: service)
    await model.load()
    model.removeCurrentTrack()
    let unconfirmedTrack = model.currentTrack
    model.removeCurrentTrack()

    await model.confirmRemovals()

    guard case .failed = model.state else {
      return XCTFail("Expected a partial failure")
    }
    XCTAssertEqual(model.stagedRemovals, [unconfirmedTrack].compactMap { $0 })
  }

  func testRetryAfterPartialSpotifyCommitReportsTotalCommittedCount() async {
    let service = SequencedCleanupLibraryService(
      tracks: [
        track(id: "one", addedAt: Date(timeIntervalSince1970: 0)),
        track(id: "two", addedAt: Date(timeIntervalSince1970: 1)),
      ]
    )
    let model = CleanupSessionModel(service: service)
    await model.load()
    model.removeCurrentTrack()
    model.removeCurrentTrack()

    await model.confirmRemovals()
    model.returnToReview()
    await model.confirmRemovals()

    XCTAssertEqual(
      model.state,
      .complete(
        .init(provider: .spotify, decisionCount: 2, result: .removed(count: 2))
      )
    )
    let committedBatches = await service.committedBatches
    XCTAssertEqual(committedBatches.map(\.count), [2, 1])
  }

  func testEmptyLibraryCompletesWithoutDecisions() async {
    let model = CleanupSessionModel(service: FakeCleanupLibraryService(tracks: []))

    await model.load()

    XCTAssertEqual(
      model.state,
      .complete(.init(provider: .spotify, decisionCount: 0, result: .noChanges))
    )
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
  nonisolated let provider: MusicProvider
  private let tracks: [LibraryTrack]
  private let loadError: (any Error)?
  private let commitResult: CleanupCommitResult?
  private let commitError: (any Error)?
  private(set) var removedURIs: [String] = []

  init(
    provider: MusicProvider = .spotify,
    tracks: [LibraryTrack],
    loadError: (any Error)? = nil,
    commitResult: CleanupCommitResult? = nil,
    commitError: (any Error)? = nil
  ) {
    self.provider = provider
    self.tracks = tracks
    self.loadError = loadError
    self.commitResult = commitResult
    self.commitError = commitError
  }

  func fetchLibraryTracks() async throws -> [LibraryTrack] {
    if let loadError { throw loadError }
    return tracks
  }

  func commit(trackIDs: [String]) async throws -> CleanupCommitResult {
    removedURIs.append(contentsOf: trackIDs)
    if let commitError { throw commitError }
    return commitResult ?? .removed(count: trackIDs.count)
  }
}

private actor SequencedCleanupLibraryService: CleanupLibraryServing {
  nonisolated let provider = MusicProvider.spotify
  private let tracks: [LibraryTrack]
  private(set) var committedBatches: [[String]] = []

  init(tracks: [LibraryTrack]) {
    self.tracks = tracks
  }

  func fetchLibraryTracks() async throws -> [LibraryTrack] {
    tracks
  }

  func commit(trackIDs: [String]) async throws -> CleanupCommitResult {
    committedBatches.append(trackIDs)
    if committedBatches.count == 1 {
      throw CleanupCommitError.partial(committedCount: 1, remainingCount: 1)
    }
    return .removed(count: trackIDs.count)
  }
}
