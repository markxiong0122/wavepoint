import SwiftUI
import XCTest

@testable import Wavepoint

final class CleanupScreenTests: XCTestCase {
  func testStateMapsToStableAccessibleScreen() {
    XCTAssertEqual(CleanupScreen(state: .idle).accessibilityIdentifier, "cleanup-loading")
    XCTAssertEqual(CleanupScreen(state: .loading).accessibilityIdentifier, "cleanup-loading")
    XCTAssertEqual(CleanupScreen(state: .deciding).accessibilityIdentifier, "cleanup-deck")
    XCTAssertEqual(CleanupScreen(state: .reviewing).accessibilityIdentifier, "cleanup-review")
    XCTAssertEqual(CleanupScreen(state: .committing).accessibilityIdentifier, "cleanup-committing")
    XCTAssertEqual(
      CleanupScreen(state: .complete(.init(decisionCount: 2, removedCount: 1)))
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
