import Foundation
import XCTest

@testable import Wavepoint

@MainActor
final class AppleMusicDumpsterServiceTests: XCTestCase {
  private let destination = URL(string: "music://playlist/dumpster")!

  func testFirstCommitCreatesDumpsterAndStoresItsID() async throws {
    let store = InMemoryDumpsterPlaylistStore()
    let client = FakeAppleMusicPlaylistClient(
      createResult: playlist(id: "dumpster", songIDs: ["one", "two"])
    )
    let service = AppleMusicDumpsterService(client: client, store: store)

    let result = try await service.commit(songIDs: ["one", "two", "one"])

    XCTAssertEqual(
      result,
      .dumpster(updatedCount: 2, destinationURL: destination)
    )
    XCTAssertEqual(store.playlistID, "dumpster")
    XCTAssertEqual(client.events, [.create(["one", "two"])])
  }

  func testExistingDumpsterMergesAndDeduplicatesSongs() async throws {
    let store = InMemoryDumpsterPlaylistStore(playlistID: "dumpster")
    let client = FakeAppleMusicPlaylistClient(
      fetchResults: [.success(playlist(id: "dumpster", songIDs: ["one", "two"]))],
      updateResults: [
        .success(playlist(id: "dumpster", songIDs: ["one", "two", "three"]))
      ]
    )
    let service = AppleMusicDumpsterService(client: client, store: store)

    let result = try await service.commit(songIDs: ["two", "three", "three"])

    XCTAssertEqual(result, .dumpster(updatedCount: 1, destinationURL: destination))
    XCTAssertEqual(
      client.events,
      [.fetch("dumpster"), .update("dumpster", ["one", "two", "three"])]
    )
  }

  func testMissingStoredPlaylistCreatesAReplacement() async throws {
    let store = InMemoryDumpsterPlaylistStore(playlistID: "deleted")
    let client = FakeAppleMusicPlaylistClient(
      fetchResults: [.success(nil)],
      createResult: playlist(id: "replacement", songIDs: ["one"])
    )
    let service = AppleMusicDumpsterService(client: client, store: store)

    let result = try await service.commit(songIDs: ["one"])

    XCTAssertEqual(result, .dumpster(updatedCount: 1, destinationURL: destination))
    XCTAssertEqual(store.playlistID, "replacement")
    XCTAssertEqual(client.events, [.fetch("deleted"), .create(["one"])])
  }

  func testUneditableStoredPlaylistCreatesAReplacement() async throws {
    let store = InMemoryDumpsterPlaylistStore(playlistID: "old")
    let client = FakeAppleMusicPlaylistClient(
      fetchResults: [.success(playlist(id: "old", songIDs: ["existing"]))],
      createResult: playlist(id: "replacement", songIDs: ["new"]),
      updateResults: [.failure(AppleMusicPlaylistClientError.notEditable)]
    )
    let service = AppleMusicDumpsterService(client: client, store: store)

    let result = try await service.commit(songIDs: ["new"])

    XCTAssertEqual(result, .dumpster(updatedCount: 1, destinationURL: destination))
    XCTAssertEqual(store.playlistID, "replacement")
    XCTAssertEqual(
      client.events,
      [.fetch("old"), .update("old", ["existing", "new"]), .create(["new"])]
    )
  }

  func testAmbiguousWriteRefetchesAndRetriesOnlyMissingSongs() async throws {
    let store = InMemoryDumpsterPlaylistStore(playlistID: "dumpster")
    let client = FakeAppleMusicPlaylistClient(
      fetchResults: [
        .success(playlist(id: "dumpster", songIDs: ["existing"])),
        .success(playlist(id: "dumpster", songIDs: ["existing", "one"])),
      ],
      updateResults: [
        .failure(DumpsterTestError.ambiguous),
        .success(playlist(id: "dumpster", songIDs: ["existing", "one", "two"])),
      ]
    )
    let service = AppleMusicDumpsterService(client: client, store: store)

    let result = try await service.commit(songIDs: ["one", "two"])

    XCTAssertEqual(result, .dumpster(updatedCount: 2, destinationURL: destination))
    XCTAssertEqual(
      client.events,
      [
        .fetch("dumpster"),
        .update("dumpster", ["existing", "one", "two"]),
        .fetch("dumpster"),
        .update("dumpster", ["existing", "one", "two"]),
      ]
    )
  }

  func testAmbiguousWriteThatActuallySucceededDoesNotDuplicateOrRetry() async throws {
    let store = InMemoryDumpsterPlaylistStore(playlistID: "dumpster")
    let client = FakeAppleMusicPlaylistClient(
      fetchResults: [
        .success(playlist(id: "dumpster", songIDs: ["existing"])),
        .success(playlist(id: "dumpster", songIDs: ["existing", "one", "two"])),
      ],
      updateResults: [.failure(DumpsterTestError.ambiguous)]
    )
    let service = AppleMusicDumpsterService(client: client, store: store)

    let result = try await service.commit(songIDs: ["one", "two"])

    XCTAssertEqual(result, .dumpster(updatedCount: 2, destinationURL: destination))
    XCTAssertEqual(client.events.filter { if case .update = $0 { true } else { false } }.count, 1)
  }

  func testEmptyCommitDoesNotCreateAPlaylist() async throws {
    let client = FakeAppleMusicPlaylistClient()
    let service = AppleMusicDumpsterService(
      client: client,
      store: InMemoryDumpsterPlaylistStore()
    )

    let result = try await service.commit(songIDs: [])

    XCTAssertEqual(result, .noChanges)
    XCTAssertTrue(client.events.isEmpty)
  }

  private func playlist(id: String, songIDs: [String]) -> AppleMusicPlaylistRecord {
    AppleMusicPlaylistRecord(id: id, destinationURL: destination, songIDs: songIDs)
  }
}

@MainActor
private final class FakeAppleMusicPlaylistClient: AppleMusicPlaylistClient {
  enum Event: Equatable {
    case fetch(String)
    case create([String])
    case update(String, [String])
  }

  private(set) var events: [Event] = []
  private var fetchResults: [Result<AppleMusicPlaylistRecord?, Error>]
  private let createResult: AppleMusicPlaylistRecord?
  private var updateResults: [Result<AppleMusicPlaylistRecord, Error>]

  init(
    fetchResults: [Result<AppleMusicPlaylistRecord?, Error>] = [],
    createResult: AppleMusicPlaylistRecord? = nil,
    updateResults: [Result<AppleMusicPlaylistRecord, Error>] = []
  ) {
    self.fetchResults = fetchResults
    self.createResult = createResult
    self.updateResults = updateResults
  }

  func fetchPlaylist(id: String) async throws -> AppleMusicPlaylistRecord? {
    events.append(.fetch(id))
    guard !fetchResults.isEmpty else { return nil }
    return try fetchResults.removeFirst().get()
  }

  func createPlaylist(name: String, songIDs: [String]) async throws
    -> AppleMusicPlaylistRecord
  {
    events.append(.create(songIDs))
    guard let createResult else { throw DumpsterTestError.missingStub }
    return createResult
  }

  func updatePlaylist(id: String, name: String, songIDs: [String]) async throws
    -> AppleMusicPlaylistRecord
  {
    events.append(.update(id, songIDs))
    guard !updateResults.isEmpty else { throw DumpsterTestError.missingStub }
    return try updateResults.removeFirst().get()
  }
}

@MainActor
private final class InMemoryDumpsterPlaylistStore: DumpsterPlaylistStoring {
  var playlistID: String?

  init(playlistID: String? = nil) {
    self.playlistID = playlistID
  }
}

private enum DumpsterTestError: Error {
  case ambiguous
  case missingStub
}
