import XCTest
@testable import Wavepoint

final class CrashReportingTests: XCTestCase {
  func testClientForwardsOnlyACoarseCategory() {
    var capturedCategory: AnalyticsErrorCategory?
    let reporter = CrashReportingClient { category in
      capturedCategory = category
    }

    reporter.record(.commit)

    XCTAssertEqual(capturedCategory, .commit)
  }
}
