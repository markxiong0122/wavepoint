import MusicKit
import OSLog

struct MusicKitAuthorizationService: AppleMusicAuthorizing {
  private let client: any MusicKitAuthorizationClient
  private let retryDelay: @Sendable () async throws -> Void

  init(
    client: any MusicKitAuthorizationClient = SystemMusicKitAuthorizationClient(),
    retryDelay: @escaping @Sendable () async throws -> Void = {
      try await Task.sleep(for: .milliseconds(300))
    }
  ) {
    self.client = client
    self.retryDelay = retryDelay
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
      let capabilities: AppleMusicSubscriptionCapabilities
      do {
        capabilities = try await fetchSubscriptionCapabilities()
      } catch AppleMusicAuthorizationClientError.permissionDenied {
        return .permissionDenied
      } catch AppleMusicAuthorizationClientError.privacyAcknowledgementRequired {
        return .privacyAcknowledgementRequired
      } catch AppleMusicAuthorizationClientError.accountNotReady {
        return .accountNotReady
      } catch AppleMusicAuthorizationClientError.serviceUnavailable {
        return .serviceUnavailable
      }
      guard capabilities.canPlayCatalogContent else {
        return .subscriptionRequired
      }
      guard capabilities.hasCloudLibraryEnabled else {
        return .syncLibraryRequired
      }
      return .eligible
    }
  }

  private func fetchSubscriptionCapabilities() async throws
    -> AppleMusicSubscriptionCapabilities
  {
    do {
      return try await client.fetchSubscriptionCapabilities()
    } catch AppleMusicAuthorizationClientError.accountNotReady {
      try await retryDelay()
      return try await client.fetchSubscriptionCapabilities()
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
    do {
      let subscription = try await MusicSubscription.current
      return AppleMusicSubscriptionCapabilities(
        canPlayCatalogContent: subscription.canPlayCatalogContent,
        hasCloudLibraryEnabled: subscription.hasCloudLibraryEnabled
      )
    } catch {
      let nsError = error as NSError
      Logger(subsystem: "ai.mapier.swipe", category: "AppleMusic").error(
        "Subscription check failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
      )
      throw Self.authorizationError(from: error)
    }
  }

  static func authorizationError(
    from error: any Error
  ) -> AppleMusicAuthorizationClientError {
    if let subscriptionError = error as? MusicSubscription.Error {
      switch subscriptionError {
      case .permissionDenied:
        return .permissionDenied
      case .privacyAcknowledgementRequired:
        return .privacyAcknowledgementRequired
      case .unknown:
        return .accountNotReady
      @unknown default:
        return .accountNotReady
      }
    }
    if let tokenError = error as? MusicTokenRequestError {
      switch tokenError {
      case .permissionDenied:
        return .permissionDenied
      case .privacyAcknowledgementRequired:
        return .privacyAcknowledgementRequired
      case .developerTokenRequestFailed:
        return .serviceUnavailable
      case .unknown, .userTokenRevoked, .userNotSignedIn, .userTokenRequestFailed:
        return .accountNotReady
      @unknown default:
        return .accountNotReady
      }
    }
    return .serviceUnavailable
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
