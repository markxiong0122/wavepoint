import Foundation

enum AppleMusicAuthorizationStatus: Equatable, Sendable {
  case notDetermined
  case denied
  case restricted
  case authorized
}

struct AppleMusicSubscriptionCapabilities: Equatable, Sendable {
  let canPlayCatalogContent: Bool
  let hasCloudLibraryEnabled: Bool
}

enum AppleMusicEligibility: Equatable, Sendable {
  case eligible
  case permissionNotDetermined
  case permissionDenied
  case restricted
  case privacyAcknowledgementRequired
  case accountNotReady
  case serviceUnavailable
  case subscriptionRequired
  case syncLibraryRequired
}

enum AppleMusicAuthorizationClientError: Error, Equatable, Sendable {
  case permissionDenied
  case privacyAcknowledgementRequired
  case accountNotReady
  case serviceUnavailable
}

protocol AppleMusicAuthorizing: Sendable {
  func currentEligibility() async throws -> AppleMusicEligibility
  func requestEligibility() async throws -> AppleMusicEligibility
}

protocol MusicKitAuthorizationClient: Sendable {
  var currentStatus: AppleMusicAuthorizationStatus { get }
  func requestAuthorization() async -> AppleMusicAuthorizationStatus
  func fetchSubscriptionCapabilities() async throws -> AppleMusicSubscriptionCapabilities
}
