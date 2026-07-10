import XCTest

@testable import Wavepoint

final class AppleMusicAuthorizationTests: XCTestCase {
  func testDeniedAndRestrictedAuthorizationMapWithoutReadingSubscription() async throws {
    let deniedClient = FakeMusicKitAuthorizationClient(
      currentStatus: .denied,
      requestedStatus: .denied
    )
    let restrictedClient = FakeMusicKitAuthorizationClient(
      currentStatus: .restricted,
      requestedStatus: .restricted
    )

    let denied = try await MusicKitAuthorizationService(client: deniedClient)
      .requestEligibility()
    let restricted = try await MusicKitAuthorizationService(client: restrictedClient)
      .currentEligibility()

    XCTAssertEqual(denied, .permissionDenied)
    XCTAssertEqual(restricted, .restricted)
  }

  func testAuthorizedAccountRequiresSubscriptionAndSyncLibrary() async throws {
    let noSubscription = MusicKitAuthorizationService(
      client: FakeMusicKitAuthorizationClient(
        currentStatus: .authorized,
        requestedStatus: .authorized,
        capabilities: .init(canPlayCatalogContent: false, hasCloudLibraryEnabled: true)
      )
    )
    let noSyncLibrary = MusicKitAuthorizationService(
      client: FakeMusicKitAuthorizationClient(
        currentStatus: .authorized,
        requestedStatus: .authorized,
        capabilities: .init(canPlayCatalogContent: true, hasCloudLibraryEnabled: false)
      )
    )
    let eligible = MusicKitAuthorizationService(
      client: FakeMusicKitAuthorizationClient(
        currentStatus: .authorized,
        requestedStatus: .authorized,
        capabilities: .init(canPlayCatalogContent: true, hasCloudLibraryEnabled: true)
      )
    )

    let noSubscriptionResult = try await noSubscription.currentEligibility()
    let noSyncLibraryResult = try await noSyncLibrary.currentEligibility()
    let eligibleResult = try await eligible.currentEligibility()

    XCTAssertEqual(noSubscriptionResult, .subscriptionRequired)
    XCTAssertEqual(noSyncLibraryResult, .syncLibraryRequired)
    XCTAssertEqual(eligibleResult, .eligible)
  }

  func testNotDeterminedStatusDoesNotPromptDuringRestore() async throws {
    let service = MusicKitAuthorizationService(
      client: FakeMusicKitAuthorizationClient(
        currentStatus: .notDetermined,
        requestedStatus: .authorized,
        capabilities: .init(canPlayCatalogContent: true, hasCloudLibraryEnabled: true)
      )
    )

    let current = try await service.currentEligibility()
    let requested = try await service.requestEligibility()

    XCTAssertEqual(current, .permissionNotDetermined)
    XCTAssertEqual(requested, .eligible)
  }

  func testPrivacyAcknowledgementErrorMapsToARecoverableEligibility() async throws {
    let service = MusicKitAuthorizationService(
      client: FakeMusicKitAuthorizationClient(
        currentStatus: .authorized,
        requestedStatus: .authorized,
        capabilitiesError: AppleMusicAuthorizationClientError
          .privacyAcknowledgementRequired
      )
    )

    let result = try await service.currentEligibility()

    XCTAssertEqual(result, .privacyAcknowledgementRequired)
  }
}

private struct FakeMusicKitAuthorizationClient: MusicKitAuthorizationClient {
  let currentStatus: AppleMusicAuthorizationStatus
  let requestedStatus: AppleMusicAuthorizationStatus
  let capabilities: AppleMusicSubscriptionCapabilities
  let capabilitiesError: AppleMusicAuthorizationClientError?

  init(
    currentStatus: AppleMusicAuthorizationStatus,
    requestedStatus: AppleMusicAuthorizationStatus,
    capabilities: AppleMusicSubscriptionCapabilities = .init(
      canPlayCatalogContent: true,
      hasCloudLibraryEnabled: true
    ),
    capabilitiesError: AppleMusicAuthorizationClientError? = nil
  ) {
    self.currentStatus = currentStatus
    self.requestedStatus = requestedStatus
    self.capabilities = capabilities
    self.capabilitiesError = capabilitiesError
  }

  func requestAuthorization() async -> AppleMusicAuthorizationStatus {
    requestedStatus
  }

  func fetchSubscriptionCapabilities() async throws -> AppleMusicSubscriptionCapabilities {
    if let capabilitiesError { throw capabilitiesError }
    return capabilities
  }
}
