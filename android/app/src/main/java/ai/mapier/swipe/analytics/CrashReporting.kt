package ai.mapier.swipe.analytics

fun interface CrashReporting {
  fun record(category: AnalyticsErrorCategory)
}

object NoOpCrashReporting : CrashReporting {
  override fun record(category: AnalyticsErrorCategory) = Unit
}

class CrashReportingClient(
  private val recordCategory: (AnalyticsErrorCategory) -> Unit,
) : CrashReporting {
  override fun record(category: AnalyticsErrorCategory) {
    recordCategory(category)
  }
}
