import Foundation
import Observation

enum MusicProviderSessionState: Equatable, Sendable {
  case restoring
  case providerPicker
  case spotifySelected
  case authorizingAppleMusic
  case appleMusicReady
  case appleMusicPermissionDenied
  case appleMusicRestricted
  case appleMusicPrivacyAcknowledgementRequired
  case appleMusicAccountNotReady
  case appleMusicServiceUnavailable
  case appleMusicSubscriptionRequired
  case appleMusicSyncLibraryRequired
  case failed(String)
}

@MainActor
protocol MusicProviderSelectionStoring: AnyObject {
  var selectedProvider: MusicProvider? { get set }
}

@MainActor
final class UserDefaultsMusicProviderSelectionStore: MusicProviderSelectionStoring {
  private let defaults: UserDefaults
  private let key: String

  init(
    defaults: UserDefaults = .standard,
    key: String = "selectedMusicProvider"
  ) {
    self.defaults = defaults
    self.key = key
  }

  var selectedProvider: MusicProvider? {
    get {
      defaults.string(forKey: key).flatMap(MusicProvider.init(rawValue:))
    }
    set {
      if let newValue {
        defaults.set(newValue.rawValue, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }
}

@MainActor
@Observable
final class MusicProviderSessionModel {
  private(set) var state: MusicProviderSessionState

  private let appleMusicAuthorizer: any AppleMusicAuthorizing
  private let selectionStore: any MusicProviderSelectionStoring
  private let analytics: any AnalyticsCapturing
  private let crashReporting: any CrashReporting

  init(
    appleMusicAuthorizer: any AppleMusicAuthorizing,
    selectionStore: any MusicProviderSelectionStoring,
    analytics: any AnalyticsCapturing = NoOpAnalytics(),
    crashReporting: any CrashReporting = NoOpCrashReporting(),
    initialState: MusicProviderSessionState = .restoring
  ) {
    self.appleMusicAuthorizer = appleMusicAuthorizer
    self.selectionStore = selectionStore
    self.analytics = analytics
    self.crashReporting = crashReporting
    state = initialState
  }

  func restore() async {
    switch selectionStore.selectedProvider {
    case nil:
      state = .providerPicker
      analytics.capture(.providerPickerViewed)
    case .spotify:
      state = .spotifySelected
    case .appleMusic:
      state = .authorizingAppleMusic
      await evaluateAppleMusic(requestPermission: false)
    }
  }

  func selectSpotify() {
    selectionStore.selectedProvider = .spotify
    state = .spotifySelected
  }

  func connectAppleMusic() async {
    analytics.capture(.providerConnectionStarted(.appleMusic))
    selectionStore.selectedProvider = .appleMusic
    state = .authorizingAppleMusic
    await evaluateAppleMusic(requestPermission: true)
  }

  func retryAppleMusicEligibility() async {
    state = .authorizingAppleMusic
    await evaluateAppleMusic(requestPermission: false)
  }

  func clearSelection() {
    selectionStore.selectedProvider = nil
    state = .providerPicker
  }

  private func evaluateAppleMusic(requestPermission: Bool) async {
    do {
      let eligibility = try await (
        requestPermission
          ? appleMusicAuthorizer.requestEligibility()
          : appleMusicAuthorizer.currentEligibility()
      )
      switch eligibility {
      case .eligible:
        state = .appleMusicReady
        analytics.capture(.providerConnectionSucceeded(.appleMusic))
      case .permissionNotDetermined:
        state = .providerPicker
      case .permissionDenied:
        state = .appleMusicPermissionDenied
        analytics.capture(.providerConnectionFailed(.appleMusic, .authorization))
      case .restricted:
        state = .appleMusicRestricted
        analytics.capture(.providerConnectionFailed(.appleMusic, .authorization))
      case .privacyAcknowledgementRequired:
        state = .appleMusicPrivacyAcknowledgementRequired
        analytics.capture(.providerConnectionFailed(.appleMusic, .eligibility))
      case .accountNotReady:
        state = .appleMusicAccountNotReady
        analytics.capture(.providerConnectionFailed(.appleMusic, .eligibility))
        crashReporting.record(.eligibility)
      case .serviceUnavailable:
        state = .appleMusicServiceUnavailable
        analytics.capture(.providerConnectionFailed(.appleMusic, .configuration))
        crashReporting.record(.configuration)
      case .subscriptionRequired:
        state = .appleMusicSubscriptionRequired
        analytics.capture(.providerConnectionFailed(.appleMusic, .eligibility))
      case .syncLibraryRequired:
        state = .appleMusicSyncLibraryRequired
        analytics.capture(.providerConnectionFailed(.appleMusic, .eligibility))
      }
    } catch is CancellationError {
      return
    } catch {
      analytics.capture(.providerConnectionFailed(.appleMusic, .unknown))
      crashReporting.record(.unknown)
      state = .failed(error.localizedDescription)
    }
  }
}
