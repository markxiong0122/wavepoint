import FirebaseCore
import FirebaseCrashlytics
import Foundation

enum FirebaseCrashReporting {
  static func make(from bundle: Bundle = .main) -> any CrashReporting {
    guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
      return NoOpCrashReporting()
    }
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    let crashlytics = Crashlytics.crashlytics()
    crashlytics.setCrashlyticsCollectionEnabled(true)

    return CrashReportingClient { category in
      crashlytics.record(
        error: NSError(
          domain: "ai.mapier.swipe.operational",
          code: category.code,
          userInfo: [NSLocalizedDescriptionKey: category.rawValue]
        )
      )
    }
  }
}

private extension AnalyticsErrorCategory {
  var code: Int {
    switch self {
    case .authorization: 1
    case .eligibility: 2
    case .libraryLoad: 3
    case .commit: 4
    case .playback: 5
    case .configuration: 6
    case .unknown: 7
    }
  }
}
