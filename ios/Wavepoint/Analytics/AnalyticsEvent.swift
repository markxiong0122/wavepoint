import Foundation

enum AnalyticsProvider: String, Sendable {
  case spotify
  case appleMusic = "apple_music"

  init(_ provider: MusicProvider) {
    self = provider == .spotify ? .spotify : .appleMusic
  }
}

enum AnalyticsErrorCategory: String, Sendable {
  case authorization
  case eligibility
  case libraryLoad = "library_load"
  case commit
  case playback
  case configuration
  case unknown
}

enum AnalyticsEvent: Equatable, Sendable {
  case appOpened
  case providerPickerViewed
  case providerConnectionStarted(AnalyticsProvider)
  case providerConnectionSucceeded(AnalyticsProvider)
  case providerConnectionFailed(AnalyticsProvider, AnalyticsErrorCategory)
  case cleanupDeckLoaded(AnalyticsProvider)
  case firstDecisionCompleted(AnalyticsProvider)
  case reviewOpened(AnalyticsProvider)
  case cleanupSessionCompleted(AnalyticsProvider)
  case cleanupSessionAbandoned(AnalyticsProvider)
  case accountDeleted

  var name: String {
    switch self {
    case .appOpened: "app_opened"
    case .providerPickerViewed: "provider_picker_viewed"
    case .providerConnectionStarted: "provider_connection_started"
    case .providerConnectionSucceeded: "provider_connection_succeeded"
    case .providerConnectionFailed: "provider_connection_failed"
    case .cleanupDeckLoaded: "cleanup_deck_loaded"
    case .firstDecisionCompleted: "first_decision_completed"
    case .reviewOpened: "review_opened"
    case .cleanupSessionCompleted: "cleanup_session_completed"
    case .cleanupSessionAbandoned: "cleanup_session_abandoned"
    case .accountDeleted: "account_deleted"
    }
  }

  var properties: [String: String] {
    switch self {
    case .providerConnectionFailed(let provider, let category):
      ["provider": provider.rawValue, "error_category": category.rawValue]
    case .providerConnectionStarted(let provider),
      .providerConnectionSucceeded(let provider),
      .cleanupDeckLoaded(let provider),
      .firstDecisionCompleted(let provider),
      .reviewOpened(let provider),
      .cleanupSessionCompleted(let provider),
      .cleanupSessionAbandoned(let provider):
      ["provider": provider.rawValue]
    case .appOpened, .providerPickerViewed, .accountDeleted:
      [:]
    }
  }
}

protocol AnalyticsCapturing: Sendable {
  func capture(_ event: AnalyticsEvent)
}

struct NoOpAnalytics: AnalyticsCapturing {
  func capture(_: AnalyticsEvent) {}
}

final class AnalyticsClient: AnalyticsCapturing, @unchecked Sendable {
  private let captureEvent: (String, [String: String]) -> Void

  init(captureEvent: @escaping (String, [String: String]) -> Void) {
    self.captureEvent = captureEvent
  }

  func capture(_ event: AnalyticsEvent) {
    captureEvent(event.name, event.properties)
  }
}

struct AnalyticsSettings: Equatable, Sendable {
  let projectToken: String
  let host: String

  var isEnabled: Bool {
    guard !projectToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let url = URL(string: host),
      url.scheme == "https",
      url.host != nil
    else {
      return false
    }
    return true
  }
}
