protocol CrashReporting: Sendable {
  func record(_ category: AnalyticsErrorCategory)
}

struct NoOpCrashReporting: CrashReporting {
  func record(_: AnalyticsErrorCategory) {}
}

final class CrashReportingClient: CrashReporting, @unchecked Sendable {
  private let recordCategory: (AnalyticsErrorCategory) -> Void

  init(recordCategory: @escaping (AnalyticsErrorCategory) -> Void) {
    self.recordCategory = recordCategory
  }

  func record(_ category: AnalyticsErrorCategory) {
    recordCategory(category)
  }
}
