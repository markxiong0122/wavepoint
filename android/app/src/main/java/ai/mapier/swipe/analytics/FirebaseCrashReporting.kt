package ai.mapier.swipe.analytics

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.crashlytics.FirebaseCrashlytics

object FirebaseCrashReporting {
  fun make(context: Context): CrashReporting {
    if (FirebaseApp.getApps(context).isEmpty()) return NoOpCrashReporting

    val crashlytics = FirebaseCrashlytics.getInstance()
    crashlytics.setCrashlyticsCollectionEnabled(true)
    return CrashReportingClient { category ->
      crashlytics.recordException(
        WavepointOperationalException(category),
      )
    }
  }
}

private class WavepointOperationalException(category: AnalyticsErrorCategory) :
  RuntimeException(category.value)
