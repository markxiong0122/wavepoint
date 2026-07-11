# Observability key handoff

No secret service-role or provider credentials belong in either app.

## PostHog

Provide the public project token and ingestion host.

- iOS: set `POSTHOG_PROJECT_TOKEN` and, if needed, `POSTHOG_HOST` in `ios/Config/Shared.xcconfig` or an uncommitted release xcconfig.
- Android: set `WAVEPOINT_POSTHOG_PROJECT_TOKEN` and optionally `WAVEPOINT_POSTHOG_HOST` in `~/.gradle/gradle.properties` or pass them as Gradle properties. The committed default stays blank.

The clients automatically become no-ops when the project token is blank.

## Firebase Crashlytics

Create one Firebase project with separate Apple and Android apps for `ai.mapier.swipe`.

- Download `GoogleService-Info.plist` to `ios/Wavepoint/Resources/`.
- Download `google-services.json` to `android/app/`.

These files are intentionally absent until supplied. iOS checks for its plist before calling Firebase. Android applies the Google Services and Crashlytics Gradle plugins only when its JSON file exists.

After configuration, force a test crash in a non-production build, confirm it arrives, and confirm iOS dSYM and Android mapping upload. Do not enable Google Analytics, Performance Monitoring, Remote Config, or Crashlytics breadcrumbs for the first release.
