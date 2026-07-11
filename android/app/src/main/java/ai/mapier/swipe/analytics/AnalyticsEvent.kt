package ai.mapier.swipe.analytics

enum class AnalyticsProvider(val value: String) {
  SPOTIFY("spotify"),
  APPLE_MUSIC("apple_music"),
}

enum class AnalyticsErrorCategory(val value: String) {
  AUTHORIZATION("authorization"),
  ELIGIBILITY("eligibility"),
  LIBRARY_LOAD("library_load"),
  COMMIT("commit"),
  PLAYBACK("playback"),
  CONFIGURATION("configuration"),
  UNKNOWN("unknown"),
}

sealed interface AnalyticsEvent {
  val name: String
  val properties: Map<String, String>

  data object AppOpened : AnalyticsEvent {
    override val name = "app_opened"
    override val properties = emptyMap<String, String>()
  }

  data object ProviderPickerViewed : AnalyticsEvent {
    override val name = "provider_picker_viewed"
    override val properties = emptyMap<String, String>()
  }

  data class ProviderConnectionStarted(val provider: AnalyticsProvider) : AnalyticsEvent {
    override val name = "provider_connection_started"
    override val properties = provider.properties
  }

  data class ProviderConnectionSucceeded(val provider: AnalyticsProvider) : AnalyticsEvent {
    override val name = "provider_connection_succeeded"
    override val properties = provider.properties
  }

  data class ProviderConnectionFailed(
    val provider: AnalyticsProvider,
    val category: AnalyticsErrorCategory,
  ) : AnalyticsEvent {
    override val name = "provider_connection_failed"
    override val properties = provider.properties + ("error_category" to category.value)
  }

  data class CleanupDeckLoaded(val provider: AnalyticsProvider) : AnalyticsEvent {
    override val name = "cleanup_deck_loaded"
    override val properties = provider.properties
  }

  data class FirstDecisionCompleted(val provider: AnalyticsProvider) : AnalyticsEvent {
    override val name = "first_decision_completed"
    override val properties = provider.properties
  }

  data class ReviewOpened(val provider: AnalyticsProvider) : AnalyticsEvent {
    override val name = "review_opened"
    override val properties = provider.properties
  }

  data class CleanupSessionCompleted(val provider: AnalyticsProvider) : AnalyticsEvent {
    override val name = "cleanup_session_completed"
    override val properties = provider.properties
  }

  data class CleanupSessionAbandoned(val provider: AnalyticsProvider) : AnalyticsEvent {
    override val name = "cleanup_session_abandoned"
    override val properties = provider.properties
  }

  data object AccountDeleted : AnalyticsEvent {
    override val name = "account_deleted"
    override val properties = emptyMap<String, String>()
  }
}

private val AnalyticsProvider.properties: Map<String, String>
  get() = mapOf("provider" to value)

fun interface AnalyticsCapturing {
  fun capture(event: AnalyticsEvent)
}

object NoOpAnalytics : AnalyticsCapturing {
  override fun capture(event: AnalyticsEvent) = Unit
}

class AnalyticsClient(
  private val captureEvent: (String, Map<String, String>) -> Unit,
) : AnalyticsCapturing {
  override fun capture(event: AnalyticsEvent) {
    captureEvent(event.name, event.properties)
  }
}

data class AnalyticsSettings(
  val projectToken: String,
  val host: String,
) {
  val isEnabled: Boolean
    get() = projectToken.isNotBlank() && runCatching {
      val uri = java.net.URI(host)
      uri.scheme == "https" && !uri.host.isNullOrBlank()
    }.getOrDefault(false)
}
