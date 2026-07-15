# Wavepoint architecture

Wavepoint has native iOS and Android clients plus two small Supabase Edge Functions. The platforms share product behavior and analytics rules, not source code.

## Product boundaries

| Concern | iOS Spotify | iOS Apple Music | Android Spotify |
| --- | --- | --- | --- |
| Authorization | Supabase Spotify OAuth | MusicKit permission and subscription checks | Supabase Spotify OAuth |
| Credential storage | iOS Keychain | Managed by MusicKit | AES-GCM with an Android Keystore key |
| Library source | Spotify saved tracks | MusicKit library songs | Spotify saved tracks |
| Playback | Spotify App Remote, with preview fallback where available | `ApplicationMusicPlayer` through MusicKit | Spotify App Remote |
| Confirmed cleanup | Remove from Spotify Liked Songs | Append only new songs to `Wavepoint Dumpster 🗑️` | Remove from Spotify Liked Songs |
| Wavepoint backend | Supabase Auth and Edge Functions | None | Supabase Auth and Edge Functions |

Apple does not expose a MusicKit API that lets Wavepoint delete songs from the main library. The Apple Music commit is therefore a staging playlist update, followed by manual **Delete from Library** in Music.

The iOS release also includes an explicit App Review demo. `ReviewDemoLibraryService` supplies fictional tracks and one bundled local audio sample to the same cleanup state machine. Its commit returns an in-memory summary only: it has no authorization, provider destination, backend request, or music-library write. `CleanupProviderPresentation.demo` keeps that distinction visible on the picker, card, review, and completion screens.

## iOS composition

`WavepointApp` constructs provider-specific clients and injects them into a provider-neutral cleanup flow:

- `MusicProviderSessionModel` owns provider selection and Apple Music eligibility states.
- `AppSessionModel` owns Spotify OAuth, token restoration, subscription eligibility, sign-out, and account deletion.
- `CleanupLibraryServing`, `LibraryTrack`, `CleanupDeckBuilder`, and `CleanupSessionModel` provide one cleanup state machine for both providers.
- `CleanupBatchPickerView` starts the shared provider load in the background while the user chooses a 10-, 25-, or 50-song deck.
- `CleanupPlaybackCoordinator` coordinates automatic 15-second playback and manual recovery without putting provider logic in the views.
- `CleanupHomeView`, `TrackCardView`, `RemovalReviewView`, and `CleanupCompleteView` render the shared flow.

Starting another batch clears the old deck, decisions, commit identifiers, counters, and manual-playback preference before loading new tracks. A failed reload cannot reopen the completed batch.

### Spotify path

Supabase completes Spotify OAuth and returns provider tokens to the app. `SpotifyCredentialProvider` reads and refreshes those credentials. `SpotifyWebAPIClient` fetches the first saved-track page, then loads remaining offset pages with at most four concurrent requests while reporting local progress. It also commits confirmed removals. `SpotifyAppRemoteService` controls the installed Spotify app for card playback.

The `spotify-token-refresh` Edge Function keeps the Spotify client secret off-device. It accepts only a valid Supabase user session and returns refreshed provider credentials.

### Apple Music path

`MusicKitAuthorizationService` maps permission, account-readiness, service, subscription, and Sync Library failures into explicit recovery screens. It retries a transient account-readiness check once.

`AppleMusicLibraryService` reads library songs, `AppleMusicTrackPlayer` controls playback, and `AppleMusicDumpsterService` owns the saved Dumpster playlist identifier. Existing playlists receive only the newly staged song IDs. If an ambiguous write occurs, the service refetches the playlist and retries only songs still missing, preventing duplicates and avoiding failures caused by old unavailable tracks.

`AppleMusicSimulatorDemo.swift` is compiled only for DEBUG Simulator builds. The `-WavepointAppleMusicDemo` launch argument replaces MusicKit with deterministic local test doubles and disables analytics/crash reporting. Release and physical-device builds always construct the real MusicKit dependencies.

## Android composition

`WavepointRuntime` constructs the Spotify, Supabase, playback, analytics, and account-deletion clients. `WavepointController` turns those services into `WavepointUiState` for the Compose screens. `CleanupDeckBuilder` and `CleanupSession` implement the same weighted 50-card, review-first behavior as iOS.

Android is Spotify-only in the current release. Apple Music support is not silently emulated or routed through the iOS implementation.

## Backend and deletion

The Supabase project provides Spotify OAuth plus two Edge Functions:

- `spotify-token-refresh`: verifies the Supabase bearer token and refreshes Spotify credentials server-side.
- `delete-account`: verifies the session, deletes the Supabase Auth user, and lets the client clear its local Spotify credentials after confirmation.

Deleting a Wavepoint account does not delete the Spotify account or songs and does not revoke the Spotify authorization grant. Apple Music users do not create a Wavepoint server account, so the Apple Music account UI does not show Supabase deletion.

## Analytics and operational data

PostHog receives only the closed event/property set in [docs/analytics-contract.md](docs/analytics-contract.md). Firebase Crashlytics receives crashes and fixed coarse incident categories. Neither integration receives music metadata or individual decisions.

Supabase Edge Functions emit a random request ID, function name, and response status. They do not log authorization headers, provider tokens, user IDs, request bodies, or music data.

Both native clients become analytics/crash no-ops when their configuration files or project tokens are absent. Production setup and rollout gates are documented in [docs/observability-setup.md](docs/observability-setup.md) and [docs/release-operations.md](docs/release-operations.md).
