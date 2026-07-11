package ai.mapier.swipe.analytics

import android.content.Context
import com.posthog.PersonProfiles
import com.posthog.PostHog
import com.posthog.android.PostHogAndroid
import com.posthog.android.PostHogAndroidConfig

object PostHogAnalytics {
  fun make(
    context: Context,
    settings: AnalyticsSettings,
  ): AnalyticsCapturing {
    if (!settings.isEnabled) return NoOpAnalytics

    val configuration = PostHogAndroidConfig(
      apiKey = settings.projectToken,
      host = settings.host,
    ).apply {
      captureApplicationLifecycleEvents = false
      captureScreenViews = false
      captureDeepLinks = false
      sessionReplay = false
      errorTrackingConfig.autoCapture = false
      sendFeatureFlagEvent = false
      preloadFeatureFlags = false
      setDefaultPersonProperties = false
      personProfiles = PersonProfiles.NEVER
    }
    PostHogAndroid.setup(context, configuration)

    return AnalyticsClient { name, properties ->
      PostHog.capture(
        event = name,
        properties = properties.mapValues { it.value as Any },
      )
    }
  }
}
