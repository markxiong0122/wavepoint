import SwiftUI
import XCTest

@testable import Wavepoint

final class CleanupScreenTests: XCTestCase {
  func testProviderPresentationUsesTruthfulSpotifyAndAppleCopy() {
    let spotify = CleanupProviderPresentation(provider: .spotify)
    let apple = CleanupProviderPresentation(provider: .appleMusic)

    XCTAssertEqual(spotify.destructiveActionLabel, "× REMOVE")
    XCTAssertEqual(spotify.reviewActionTitle(count: 3), "REMOVE 3 FROM LIKED SONGS")
    XCTAssertEqual(spotify.completionTitle(hasDecisions: true), "That feels lighter.")
    XCTAssertEqual(spotify.destinationActionTitle, "OPEN IN SPOTIFY")

    XCTAssertEqual(apple.destructiveActionLabel, "× TOSS")
    XCTAssertEqual(apple.reviewActionTitle(count: 3), "SEND 3 TO THE DUMPSTER")
    XCTAssertEqual(apple.completionTitle(hasDecisions: true), "DUMPSTER READY")
    XCTAssertEqual(apple.destinationActionTitle, "OPEN IN MUSIC")
    XCTAssertTrue(apple.reviewTrustCopy.contains("songs stay in your Library"))
    XCTAssertTrue(apple.completionInstructions.contains("Delete from Library"))
    XCTAssertTrue(apple.completionInstructions.contains("Remove from Playlist alone"))
  }

  func testStateMapsToStableAccessibleScreen() {
    XCTAssertEqual(CleanupScreen(state: .idle).accessibilityIdentifier, "cleanup-loading")
    XCTAssertEqual(CleanupScreen(state: .loading).accessibilityIdentifier, "cleanup-loading")
    XCTAssertEqual(CleanupScreen(state: .deciding).accessibilityIdentifier, "cleanup-deck")
    XCTAssertEqual(CleanupScreen(state: .reviewing).accessibilityIdentifier, "cleanup-review")
    XCTAssertEqual(CleanupScreen(state: .committing).accessibilityIdentifier, "cleanup-committing")
    XCTAssertEqual(
      CleanupScreen(
        state: .complete(
          .init(provider: .spotify, decisionCount: 2, result: .removed(count: 1))
        )
      )
        .accessibilityIdentifier,
      "cleanup-complete"
    )
    XCTAssertEqual(
      CleanupScreen(state: .failed("Try again")).accessibilityIdentifier,
      "cleanup-error"
    )
  }

  func testPlaybackStateMapsToStartingDeckOrFailure() {
    XCTAssertEqual(CleanupPlaybackScreen(state: .idle), .starting)
    XCTAssertEqual(CleanupPlaybackScreen(state: .starting), .starting)
    XCTAssertEqual(CleanupPlaybackScreen(state: .automatic), .deck)
    XCTAssertEqual(CleanupPlaybackScreen(state: .manual), .deck)
    XCTAssertEqual(
      CleanupPlaybackScreen(state: .failed("Try Spotify again.")),
      .failed("Try Spotify again.")
    )
  }

  @MainActor
  func testArtworkImageFillsACompressedWideSlot() throws {
    let source = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
    }
    let renderer = ImageRenderer(
      content: TrackArtworkImage(image: Image(uiImage: source))
        .frame(width: 120, height: 80)
        .background(Color.white)
    )
    renderer.scale = 1

    let image = try XCTUnwrap(renderer.uiImage?.cgImage)
    let color = try pixelColor(in: image, x: 119, y: 40)

    XCTAssertGreaterThan(color.red, 200)
    XCTAssertLessThan(color.green, 30)
    XCTAssertLessThan(color.blue, 30)
  }

  private func pixelColor(
    in image: CGImage,
    x: Int,
    y: Int
  ) throws -> (red: UInt8, green: UInt8, blue: UInt8) {
    let data = try XCTUnwrap(image.dataProvider?.data)
    let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
    let offset = y * image.bytesPerRow + x * 4
    return (bytes[offset], bytes[offset + 1], bytes[offset + 2])
  }
}
