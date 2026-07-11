# Wavepoint analytics contract

Wavepoint analytics measure the app's reliability and generic cleanup funnel. They must never become music analytics.

## Allowed events

| Event | Allowed properties |
| --- | --- |
| `app_opened` | none |
| `provider_picker_viewed` | none |
| `provider_connection_started` | `provider` |
| `provider_connection_succeeded` | `provider` |
| `provider_connection_failed` | `provider`, `error_category` |
| `cleanup_deck_loaded` | `provider` |
| `first_decision_completed` | `provider` |
| `review_opened` | `provider` |
| `cleanup_session_completed` | `provider` |
| `cleanup_session_abandoned` | `provider` |
| `account_deleted` | none |

Allowed provider values are `spotify` and `apple_music`. Allowed error categories are closed enums in the native clients.

## Prohibited data

Never capture track or album IDs, URIs, names, artists, artwork, saved dates, library size, listening history, playback state/history, removal totals, decision totals, individual Keep/Remove choices, provider user IDs, Supabase user IDs, names, emails, access/refresh tokens, raw URLs, raw errors, or provider response bodies.

PostHog configuration must keep lifecycle/screen/deep-link autocapture, replay, surveys, feature flags, swizzling, and person profiles disabled. Do not call `identify`.

## Product definitions

- Activation: provider connection succeeded and first cleanup session completed.
- Time to value: first decision after initial app open. Analyze this as a funnel, not by attaching timestamps or music properties to an individual.
- Repeat value: another completed cleanup session within 14 or 30 days.
- North star: weekly anonymous installations completing a cleanup session.
- Stability: crash-free sessions and users by app version.

Wavepoint is episodic. D1 opens are a secondary store metric, not the product's north star.
