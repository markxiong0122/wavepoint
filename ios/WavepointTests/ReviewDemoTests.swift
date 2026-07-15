import Foundation
import XCTest

@testable import Wavepoint

final class ReviewDemoTests: XCTestCase {
  func testDemoBuildsAFictionalLocalDeckWithoutProviderDestinations() async throws {
    let previewURL = URL(fileURLWithPath: "/wavepoint-demo-preview.m4a")
    let service = ReviewDemoLibraryService(previewURL: previewURL)

    let tracks = try await service.fetchLibraryTracks()

    XCTAssertEqual(tracks.count, 50)
    XCTAssertEqual(Set(tracks.map(\.id)).count, 50)
    XCTAssertTrue(tracks.allSatisfy { $0.previewURL == previewURL })
    XCTAssertTrue(tracks.allSatisfy { $0.destinationURL == nil })
    XCTAssertTrue(tracks.allSatisfy { $0.playbackID.isEmpty })
  }

  func testDemoCommitOnlyReturnsALocalSummary() async throws {
    let service = ReviewDemoLibraryService(
      previewURL: URL(fileURLWithPath: "/wavepoint-demo-preview.m4a")
    )

    let result = try await service.commit(trackIDs: ["demo-1", "demo-2"])

    XCTAssertEqual(result, .removed(count: 2))
  }

  func testDemoFailsClearlyWhenBundledPreviewIsMissing() async {
    let service = ReviewDemoLibraryService(previewURL: nil)

    do {
      _ = try await service.fetchLibraryTracks()
      XCTFail("Expected a missing-preview error")
    } catch {
      XCTAssertEqual(error as? ReviewDemoError, .missingPreview)
    }
  }
}
