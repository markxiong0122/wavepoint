import Foundation
import PostHog

enum PostHogAnalytics {
  static func make(from bundle: Bundle = .main) -> any AnalyticsCapturing {
    let settings = AnalyticsSettings(
      projectToken: bundle.object(forInfoDictionaryKey: "POSTHOG_PROJECT_TOKEN") as? String ?? "",
      host: bundle.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String ?? ""
    )
    guard settings.isEnabled else { return NoOpAnalytics() }

    let configuration = PostHogConfig(
      projectToken: settings.projectToken,
      host: settings.host
    )
    configuration.captureApplicationLifecycleEvents = false
    configuration.captureScreenViews = false
    configuration.captureElementInteractions = false
    configuration.enableSwizzling = false
    configuration.sendFeatureFlagEvent = false
    configuration.preloadFeatureFlags = false
    configuration.setDefaultPersonProperties = false
    configuration.sessionReplay = false
    configuration.surveys = false
    PostHogSDK.shared.setup(configuration)

    return AnalyticsClient { name, properties in
      PostHogSDK.shared.capture(
        name,
        properties: properties.mapValues { $0 as Any }
      )
    }
  }
}
