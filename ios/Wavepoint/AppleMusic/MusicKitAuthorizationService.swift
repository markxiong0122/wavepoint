import MusicKit

struct MusicKitAuthorizationService: AppleMusicAuthorizing {
  private let client: any MusicKitAuthorizationClient

  init(client: any MusicKitAuthorizationClient = SystemMusicKitAuthorizationClient()) {
    self.client = client
  }

  func currentEligibility() async throws -> AppleMusicEligibility {
    try await eligibility(for: client.currentStatus)
  }

  func requestEligibility() async throws -> AppleMusicEligibility {
    try await eligibility(for: await client.requestAuthorization())
  }

  private func eligibility(
    for status: AppleMusicAuthorizationStatus
  ) async throws -> AppleMusicEligibility {
    switch status {
    case .notDetermined:
      return .permissionNotDetermined
    case .denied:
      return .permissionDenied
    case .restricted:
      return .restricted
    case .authorized:
      let capabilities = try await client.fetchSubscriptionCapabilities()
      guard capabilities.canPlayCatalogContent else {
        return .subscriptionRequired
      }
      guard capabilities.hasCloudLibraryEnabled else {
        return .syncLibraryRequired
      }
      return .eligible
    }
  }
}

struct SystemMusicKitAuthorizationClient: MusicKitAuthorizationClient {
  var currentStatus: AppleMusicAuthorizationStatus {
    Self.status(from: MusicAuthorization.currentStatus)
  }

  func requestAuthorization() async -> AppleMusicAuthorizationStatus {
    Self.status(from: await MusicAuthorization.request())
  }

  func fetchSubscriptionCapabilities() async throws -> AppleMusicSubscriptionCapabilities {
    let subscription = try await MusicSubscription.current
    return AppleMusicSubscriptionCapabilities(
      canPlayCatalogContent: subscription.canPlayCatalogContent,
      hasCloudLibraryEnabled: subscription.hasCloudLibraryEnabled
    )
  }

  private static func status(
    from status: MusicAuthorization.Status
  ) -> AppleMusicAuthorizationStatus {
    switch status {
    case .notDetermined:
      .notDetermined
    case .denied:
      .denied
    case .restricted:
      .restricted
    case .authorized:
      .authorized
    @unknown default:
      .restricted
    }
  }
}
