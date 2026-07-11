package ai.mapier.swipe.analytics

import org.junit.Assert.assertEquals
import org.junit.Test

class CrashReportingTest {
  @Test
  fun clientForwardsOnlyACoarseCategory() {
    var capturedCategory: AnalyticsErrorCategory? = null
    val reporter = CrashReportingClient { category -> capturedCategory = category }

    reporter.record(AnalyticsErrorCategory.COMMIT)

    assertEquals(AnalyticsErrorCategory.COMMIT, capturedCategory)
  }
}
