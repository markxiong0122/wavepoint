import Foundation
@testable import Wavepoint

final class RecordingAnalytics: AnalyticsCapturing, @unchecked Sendable {
  private let lock = NSLock()
  private var capturedEvents: [AnalyticsEvent] = []

  var events: [AnalyticsEvent] {
    lock.withLock { capturedEvents }
  }

  func capture(_ event: AnalyticsEvent) {
    lock.withLock { capturedEvents.append(event) }
  }
}

final class RecordingCrashReporting: CrashReporting, @unchecked Sendable {
  private let lock = NSLock()
  private var capturedCategories: [AnalyticsErrorCategory] = []

  var categories: [AnalyticsErrorCategory] {
    lock.withLock { capturedCategories }
  }

  func record(_ category: AnalyticsErrorCategory) {
    lock.withLock { capturedCategories.append(category) }
  }
}
