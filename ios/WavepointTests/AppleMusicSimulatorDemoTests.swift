#if DEBUG && targetEnvironment(simulator)
  import XCTest

  @testable import Wavepoint

  @MainActor
  final class AppleMusicSimulatorDemoTests: XCTestCase {
    func testLaunchArgumentDefaultsToEligibleAndMapsRecoveryStates() {
      XCTAssertNil(AppleMusicSimulatorDemo.scenario(arguments: ["Wavepoint"]))
      XCTAssertEqual(
        AppleMusicSimulatorDemo.scenario(arguments: [
          "Wavepoint", "-WavepointAppleMusicDemo",
        ]),
        .eligible
      )

      let scenarios: [(String, AppleMusicSimulatorDemoScenario)] = [
        ("eligible", .eligible),
        ("permission-denied", .permissionDenied),
        ("account-not-ready", .accountNotReady),
        ("service-unavailable", .serviceUnavailable),
        ("subscription-required", .subscriptionRequired),
        ("sync-library-required", .syncLibraryRequired),
      ]
      for (argument, expected) in scenarios {
        XCTAssertEqual(
          AppleMusicSimulatorDemo.scenario(arguments: [
            "Wavepoint", "-WavepointAppleMusicDemo", argument,
          ]),
          expected
        )
      }
    }

    func testEligibleDemoDrivesTheRealSessionAndCleanupModels() async {
      let dependencies = AppleMusicSimulatorDemo.dependencies(for: .eligible)
      let providerModel = MusicProviderSessionModel(
        appleMusicAuthorizer: dependencies.authorizer,
        selectionStore: dependencies.selectionStore
      )
      let cleanupModel = CleanupSessionModel(service: dependencies.cleanupService)

      await providerModel.restore()
      await cleanupModel.load()
      cleanupModel.removeCurrentTrack()
      cleanupModel.beginReview()
      await cleanupModel.confirmRemovals()

      XCTAssertEqual(providerModel.state, .appleMusicReady)
      XCTAssertEqual(cleanupModel.provider, .appleMusic)
      guard case .complete(let summary) = cleanupModel.state else {
        return XCTFail("Expected the demo cleanup to complete")
      }
      guard case .dumpster(let updatedCount, _) = summary.result else {
        return XCTFail("Expected a Dumpster result")
      }
      XCTAssertEqual(updatedCount, 1)
    }

    func testRecoveryScenariosExposeExistingEligibilityStates() async throws {
      let scenarios: [(AppleMusicSimulatorDemoScenario, AppleMusicEligibility)] = [
        (.permissionDenied, .permissionDenied),
        (.accountNotReady, .accountNotReady),
        (.serviceUnavailable, .serviceUnavailable),
        (.subscriptionRequired, .subscriptionRequired),
        (.syncLibraryRequired, .syncLibraryRequired),
      ]

      for (scenario, expected) in scenarios {
        let authorizer = AppleMusicSimulatorDemo.dependencies(for: scenario).authorizer
        let eligibility = try await authorizer.currentEligibility()
        XCTAssertEqual(eligibility, expected)
      }
    }
  }
#endif
