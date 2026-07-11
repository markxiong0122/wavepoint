package ai.mapier.swipe.analytics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AnalyticsEventTest {
  @Test
  fun eventContractUsesOnlyApprovedNamesAndProperties() {
    val events = listOf(
      Triple(AnalyticsEvent.AppOpened, "app_opened", emptyMap()),
      Triple(AnalyticsEvent.ProviderPickerViewed, "provider_picker_viewed", emptyMap()),
      Triple(
        AnalyticsEvent.ProviderConnectionStarted(AnalyticsProvider.SPOTIFY),
        "provider_connection_started",
        mapOf("provider" to "spotify"),
      ),
      Triple(
        AnalyticsEvent.ProviderConnectionSucceeded(AnalyticsProvider.APPLE_MUSIC),
        "provider_connection_succeeded",
        mapOf("provider" to "apple_music"),
      ),
      Triple(
        AnalyticsEvent.ProviderConnectionFailed(
          AnalyticsProvider.SPOTIFY,
          AnalyticsErrorCategory.AUTHORIZATION,
        ),
        "provider_connection_failed",
        mapOf("provider" to "spotify", "error_category" to "authorization"),
      ),
      Triple(
        AnalyticsEvent.CleanupDeckLoaded(AnalyticsProvider.SPOTIFY),
        "cleanup_deck_loaded",
        mapOf("provider" to "spotify"),
      ),
      Triple(
        AnalyticsEvent.FirstDecisionCompleted(AnalyticsProvider.SPOTIFY),
        "first_decision_completed",
        mapOf("provider" to "spotify"),
      ),
      Triple(
        AnalyticsEvent.ReviewOpened(AnalyticsProvider.SPOTIFY),
        "review_opened",
        mapOf("provider" to "spotify"),
      ),
      Triple(
        AnalyticsEvent.CleanupSessionCompleted(AnalyticsProvider.APPLE_MUSIC),
        "cleanup_session_completed",
        mapOf("provider" to "apple_music"),
      ),
      Triple(
        AnalyticsEvent.CleanupSessionAbandoned(AnalyticsProvider.SPOTIFY),
        "cleanup_session_abandoned",
        mapOf("provider" to "spotify"),
      ),
      Triple(AnalyticsEvent.AccountDeleted, "account_deleted", emptyMap()),
    )

    events.forEach { (event, name, properties) ->
      assertEquals(name, event.name)
      assertEquals(properties, event.properties)
      assertTrue(event.properties.keys.all { it in setOf("provider", "error_category") })
    }
  }

  @Test
  fun clientForwardsOnlyTheClosedEventPayload() {
    var capturedName: String? = null
    var capturedProperties: Map<String, String>? = null
    val client = AnalyticsClient { name, properties ->
      capturedName = name
      capturedProperties = properties
    }

    client.capture(
      AnalyticsEvent.ProviderConnectionFailed(
        AnalyticsProvider.SPOTIFY,
        AnalyticsErrorCategory.ELIGIBILITY,
      ),
    )

    assertEquals("provider_connection_failed", capturedName)
    assertEquals(
      mapOf("provider" to "spotify", "error_category" to "eligibility"),
      capturedProperties,
    )
  }

  @Test
  fun settingsRequireBothAProjectTokenAndHttpsHost() {
    assertEquals(false, AnalyticsSettings("", "https://us.i.posthog.com").isEnabled)
    assertEquals(false, AnalyticsSettings("phc_test", "http://example.com").isEnabled)
    assertEquals(true, AnalyticsSettings("phc_test", "https://us.i.posthog.com").isEnabled)
  }
}
