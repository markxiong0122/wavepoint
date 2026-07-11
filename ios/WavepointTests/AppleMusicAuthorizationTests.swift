import MusicKit
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

  func testMusicKitSubscriptionErrorsMapToActionableConnectionStates() {
    XCTAssertEqual(
      SystemMusicKitAuthorizationClient.authorizationError(
        from: MusicSubscription.Error.permissionDenied
      ),
      .permissionDenied
    )
    XCTAssertEqual(
      SystemMusicKitAuthorizationClient.authorizationError(
        from: MusicSubscription.Error.privacyAcknowledgementRequired
      ),
      .privacyAcknowledgementRequired
    )
    XCTAssertEqual(
      SystemMusicKitAuthorizationClient.authorizationError(
        from: MusicSubscription.Error.unknown
      ),
      .accountNotReady
    )
    XCTAssertEqual(
      SystemMusicKitAuthorizationClient.authorizationError(
        from: MusicTokenRequestError.developerTokenRequestFailed
      ),
      .serviceUnavailable
    )
    XCTAssertEqual(
      SystemMusicKitAuthorizationClient.authorizationError(
        from: MusicTokenRequestError.userNotSignedIn
      ),
      .accountNotReady
    )
  }

  func testAccountNotReadyErrorMapsToRecoverableEligibility() async throws {
    let service = MusicKitAuthorizationService(
      client: FakeMusicKitAuthorizationClient(
        currentStatus: .authorized,
        requestedStatus: .authorized,
        capabilitiesError: .accountNotReady
      ),
      retryDelay: {}
    )

    let result = try await service.currentEligibility()

    XCTAssertEqual(result, .accountNotReady)
  }

  func testAccountReadinessGetsOneBoundedRetry() async throws {
    let client = SequencedMusicKitAuthorizationClient(results: [
      .failure(.accountNotReady),
      .success(.init(canPlayCatalogContent: true, hasCloudLibraryEnabled: true)),
    ])
    let service = MusicKitAuthorizationService(client: client, retryDelay: {})

    let result = try await service.currentEligibility()

    XCTAssertEqual(result, .eligible)
    let requestCount = await client.requestCount
    XCTAssertEqual(requestCount, 2)
  }
}

private actor SequencedMusicKitAuthorizationClient: MusicKitAuthorizationClient {
  nonisolated let currentStatus = AppleMusicAuthorizationStatus.authorized
  private var results: [Result<AppleMusicSubscriptionCapabilities, AppleMusicAuthorizationClientError>]
  private(set) var requestCount = 0

  init(
    results: [Result<AppleMusicSubscriptionCapabilities, AppleMusicAuthorizationClientError>]
  ) {
    self.results = results
  }

  func requestAuthorization() async -> AppleMusicAuthorizationStatus {
    .authorized
  }

  func fetchSubscriptionCapabilities() async throws -> AppleMusicSubscriptionCapabilities {
    requestCount += 1
    return try results.removeFirst().get()
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
