# Wavepoint release operations

## Dashboards

Create these after PostHog and Firebase keys are installed:

1. PostHog activation funnel: `app_opened` → `provider_connection_succeeded` → `cleanup_deck_loaded` → `first_decision_completed` → `review_opened` → `cleanup_session_completed`.
2. PostHog 14-day and 30-day retention using `cleanup_session_completed` as both start and return event.
3. Connection reliability by provider and coarse error category.
4. Firebase Crashlytics crash-free users and sessions by release.
5. App Store Connect downloads, conversion, retention, and crashes by version.
6. Play Console acquisition plus Android Vitals crash/ANR metrics by release track.
7. Supabase Edge Function status counts using the structured `edge_function_request` logs.

## Alerts and stop-ship gates

- Any new fatal crash affecting multiple users: investigate before expanding rollout.
- Crash-free sessions below 99.5%: stop rollout.
- Provider connection success below 90% or a 10-point release-over-release drop: stop rollout.
- Cleanup deck load success below 95%: stop rollout.
- Supabase Edge Function 5xx responses above 2% over 15 minutes: investigate and pause Spotify rollout.
- Android user-perceived crash rate approaching 1% or ANR rate approaching 0.4%: stop rollout before Play's bad-behavior thresholds.

Check dashboards daily for the first seven days, then weekly. Do not alert on user-, song-, or decision-level behavior.

## Rollout

1. TestFlight/Internal testing with configured analytics and Crashlytics.
2. Force one non-production test crash per platform and confirm symbolication.
3. Confirm one event from every allowed funnel step and inspect its properties.
4. Confirm no PostHog autocapture, replay, persons, or feature-flag traffic appears.
5. Release iOS manually, initially using phased release.
6. Release Android to internal, then closed testing, then a small staged production percentage.
7. Expand only while the stop-ship gates remain green.

## Incident handling

Record the affected platform, build, provider, coarse failure category, start/end time, user impact, mitigation, and follow-up. Never paste provider tokens, authorization headers, music-library screenshots, or raw Supabase Auth records into an incident document.
