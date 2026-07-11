import Foundation
import XCTest

final class ProjectConfigurationTests: XCTestCase {
  func testReleaseConfigurationIncludesAppleMusicAndIPhoneSettings() throws {
    let projectFile = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("project.yml")
    let contents = try String(contentsOf: projectFile, encoding: .utf8)

    XCTAssertTrue(contents.contains("NSAppleMusicUsageDescription:"))
    XCTAssertTrue(contents.contains("CURRENT_PROJECT_VERSION: 6"))
    XCTAssertTrue(contents.contains("PRODUCT_BUNDLE_IDENTIFIER: ai.mapier.swipe"))
    XCTAssertTrue(contents.contains("TARGETED_DEVICE_FAMILY: 1"))
  }

  func testAppleMusicDemoSourceIsDebugSimulatorGated() throws {
    let sourceFile = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Wavepoint/App/AppleMusicSimulatorDemo.swift")
    let contents = try String(contentsOf: sourceFile, encoding: .utf8)

    XCTAssertTrue(contents.contains("#if DEBUG && targetEnvironment(simulator)"))
    XCTAssertTrue(contents.contains("-WavepointAppleMusicDemo"))
  }
}
