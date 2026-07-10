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

  init(
    appleMusicAuthorizer: any AppleMusicAuthorizing,
    selectionStore: any MusicProviderSelectionStoring,
    initialState: MusicProviderSessionState = .restoring
  ) {
    self.appleMusicAuthorizer = appleMusicAuthorizer
    self.selectionStore = selectionStore
    state = initialState
  }

  func restore() async {
    switch selectionStore.selectedProvider {
    case nil:
      state = .providerPicker
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
      case .permissionNotDetermined:
        state = .providerPicker
      case .permissionDenied:
        state = .appleMusicPermissionDenied
      case .restricted:
        state = .appleMusicRestricted
      case .privacyAcknowledgementRequired:
        state = .appleMusicPrivacyAcknowledgementRequired
      case .subscriptionRequired:
        state = .appleMusicSubscriptionRequired
      case .syncLibraryRequired:
        state = .appleMusicSyncLibraryRequired
      }
    } catch is CancellationError {
      return
    } catch {
      state = .failed(error.localizedDescription)
    }
  }
}
