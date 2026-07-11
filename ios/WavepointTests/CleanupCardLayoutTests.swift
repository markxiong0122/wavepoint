import XCTest

@testable import Wavepoint

final class CleanupCardLayoutTests: XCTestCase {
  func testCurrentPhoneHeightReservesDetailsAndPosterShadow() {
    let layout = CleanupCardLayout(
      availableSize: CGSize(width: 357, height: 465),
      detailHeight: 260,
      shadowDepth: 7
    )

    XCTAssertGreaterThan(layout.artworkHeight, 0)
    XCTAssertLessThanOrEqual(layout.artworkHeight, 357)
    XCTAssertLessThanOrEqual(layout.cardHeight + layout.bottomClearance, 465)
    XCTAssertEqual(layout.bottomClearance, 7)
  }

  func testShortPhoneHeightShrinksArtworkBeforeDetails() {
    let layout = CleanupCardLayout(
      availableSize: CGSize(width: 320, height: 390),
      detailHeight: 260,
      shadowDepth: 7
    )

    XCTAssertEqual(layout.artworkHeight, 123)
    XCTAssertEqual(layout.cardHeight, 383)
    XCTAssertEqual(layout.bottomClearance, 7)
  }

  func testArtworkNeverBecomesNegativeWhenSpaceIsConstrained() {
    let layout = CleanupCardLayout(
      availableSize: CGSize(width: 320, height: 200),
      detailHeight: 260,
      shadowDepth: 7
    )

    XCTAssertEqual(layout.artworkHeight, 0)
    XCTAssertEqual(layout.cardHeight, 193)
    XCTAssertEqual(layout.bottomClearance, 7)
  }
}
