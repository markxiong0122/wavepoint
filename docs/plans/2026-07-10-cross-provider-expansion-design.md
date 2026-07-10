# Cross-Provider Expansion Design

## Status

Approved on 2026-07-10.

## Product outcome

Wavepoint becomes one public music-cleanup product with the same fast deck, listening segment, swipe decisions, undo, review, and explicit commit boundary across supported providers.

- iOS supports Spotify Premium and Apple Music.
- Android supports Spotify Premium only.
- Spotify removes confirmed songs from Liked Songs automatically.
- Apple Music cannot remove library songs through a public API, so confirmed candidates are sent to an app-owned playlist named `Wavepoint Dumpster 🗑️` for a clearly disclosed manual finish in Music.

The primary measure remains confident song decisions per minute. Provider support must not weaken the promise by turning a capability limitation into a silent timeout or a fake success state.

## Evidence and platform limits

### Spotify

Spotify App Remote provides on-demand playback only for eligible accounts. Wavepoint must request `user-read-private`, fetch `GET /v1/me`, and require the returned subscription product to be `premium` before the cleanup flow begins. A Free or Open account receives a provider-specific blocker instead of reaching the existing 15-second App Remote timeout. Spotify marks the `product` field deprecated, so a missing or unknown value maps to `SUBSCRIPTION COULD NOT BE VERIFIED` with retry/reconnect actions rather than being mislabeled as Free.

The Web API continues to provide saved-track pagination, recent listening evidence, and confirmed library removal through `DELETE /v1/me/library`.

### Apple Music

MusicKit provides all of the read and playback inputs Wavepoint needs:

- `MusicAuthorization` for accountless library permission;
- `MusicSubscription.current` for `canPlayCatalogContent` and `hasCloudLibraryEnabled` eligibility;
- `MusicLibraryRequest<Song>` for library pagination;
- `Song.libraryAddedDate`, `Song.lastPlayedDate`, and recent-song requests for weighting;
- artwork, artist, duration, Music URL, and targeted playback through a MusicKit player.

Apple's public `MusicLibrary` interface exposes add, playlist creation, and editing of playlists created by the same app. It does not expose removing a song from the user's main library. Private or undocumented endpoints are not acceptable for a public App Store product.

Sources:

- https://developer.apple.com/documentation/musickit/musiclibrary
- https://developer.apple.com/documentation/musickit/musiclibraryrequest
- https://developer.apple.com/documentation/musickit/musicsubscription
- https://developer.apple.com/documentation/musickit/song/libraryaddeddate
- https://developer.apple.com/documentation/musickit/song/lastplayeddate
- https://developer.spotify.com/documentation/web-api/reference/get-current-users-profile
- https://developer.spotify.com/documentation/web-api/concepts/quota-modes
- https://developer.spotify.com/documentation/android/tutorials/getting-started
- https://supabase.com/docs/guides/auth/social-login

## Experience

### Provider entry on iOS

The existing Cut Record login screen keeps its visual hierarchy and adds two equal provider actions:

1. `CONTINUE WITH SPOTIFY`
   - Supporting copy: `Spotify Premium required.`
2. `CONTINUE WITH APPLE MUSIC`
   - Supporting copy: `Apple Music subscription and Sync Library required.`

Apple Music is accountless in this version. Supabase remains part of the Spotify path only. The selected provider is stored locally so a restored session returns to the correct adapter. The Account sheet exposes `CHANGE MUSIC SERVICE`; disconnecting Apple Music clears Wavepoint's local provider/session state but explains that permission itself is managed in iOS Settings.

### Spotify eligibility

After Spotify OAuth returns provider tokens, but before Wavepoint enters cleanup:

1. Fetch the current profile with `user-read-private` scope.
2. Accept only `premium`.
3. On `free` or `open`, clear the unusable Supabase session and provider credentials.
4. Show `SPOTIFY PREMIUM REQUIRED` with actions for `TRY ANOTHER SPOTIFY ACCOUNT` and `USE APPLE MUSIC` on iOS.

If `product` is absent, unknown, or the profile request receives a non-authentication failure, preserve the local session long enough to offer retry, but do not enter cleanup. A `403` from a Development Mode app also explains that the account may not be on the app's tester allowlist.

Restored Spotify sessions are checked again to catch subscription changes. Tokens created before `user-read-private` was added receive `RECONNECT SPOTIFY TO CHECK PREMIUM`, not a generic error.

### Apple Music eligibility

The Apple path requests `MusicAuthorization`, then checks the current subscription:

- Permission denied or restricted: explain how to enable Media & Apple Music access in Settings.
- `canPlayCatalogContent == false`: show `APPLE MUSIC SUBSCRIPTION REQUIRED` and allow choosing Spotify.
- `hasCloudLibraryEnabled == false`: show `TURN ON SYNC LIBRARY` with concise Music settings guidance.
- Eligible: load the cleanup deck.

### Shared cleanup loop

Both iOS providers and Android Spotify use the same product behavior:

1. Build a deck of up to 50 songs from the full accessible library.
2. Weight old additions and songs outside recent rotation more heavily.
3. Present the same artwork-first card.
4. Target a 15-second segment while the card is active; startup, seek completion, cancellation, and unavailable items make frame-exact timing an invalid promise.
5. Swipe or tap Keep/Remove, with Undo available.
6. Stage all destructive or removal-like decisions locally.
7. Review the exact staged set.
8. Commit only after an explicit confirmation.

Provider names, attribution, and destination links may differ, but card geometry, gestures, colors, progress, and decision semantics stay aligned.

### Spotify commit

- Swipe label: `REMOVE`
- Review action: `REMOVE {N} FROM LIKED SONGS`
- Result: songs are removed automatically from Spotify after confirmation.
- Completion: reports the exact committed count and any partial failure.

### Apple Music Dumpster commit

- Swipe label: `TOSS`
- Review action: `SEND {N} TO THE DUMPSTER`
- Trust copy before confirmation: `Apple doesn't let Wavepoint remove these automatically. This creates or updates a playlist; the songs stay in your Library until you delete them in Music.`
- First commit creates `Wavepoint Dumpster 🗑️` with the staged songs.
- Later commits locate the stored app-created playlist, merge new songs, and deduplicate entries.
- If the stored playlist no longer exists or is no longer editable, create a new Dumpster and update the local identifier.
- Completion title: `DUMPSTER READY`
- Completion action: `OPEN IN MUSIC`
- Completion instructions: `In the Dumpster, touch and hold each song and choose Delete from Library. Remove from Playlist alone does not delete it from your Library.`

Wavepoint must never report Apple Music songs as deleted.

## Shared iOS architecture

### Provider-neutral domain

Replace Spotify-shaped cleanup types with provider-neutral domain values:

- `MusicProvider`: `.spotify` or `.appleMusic`
- `LibraryTrack`: provider ID, playback ID, title, artists, artwork URL/template, destination URL, duration, added date, and provider
- `CleanupCommit`: staged provider IDs plus provider-specific metadata
- `CleanupCommitResult`: automatic removals or Dumpster update with count and destination URL

`CleanupDeckBuilder` and `CleanupSessionModel` continue to own ranking and session state. Each provider paginates the complete accessible song library, combines it with up to 50 recent items, weights the full candidate set, and then selects at most 50 cards. This keeps old buried songs eligible instead of weighting only the first API page. They depend on protocols rather than Spotify-specific concrete types:

- authorization/session eligibility;
- library fetch and recent evidence;
- track playback;
- commit staged removals;
- provider destination/open action.

The refactor must preserve the existing Spotify behavior before Apple Music is connected.

### Spotify adapter

The Spotify adapter wraps the existing Supabase authenticator, Keychain token store, Web API client, credential refresh, and App Remote playback. The new subscription check is a Web API boundary and is independently testable.

### Apple Music adapter

The Apple adapter wraps MusicKit behind small protocols so domain tests do not require a live Apple Music account:

- authorization and subscription facade;
- paginated library/recent-song facade;
- application player facade with a cancellation-safe targeted 15-second stop;
- Dumpster playlist facade.

The app adds the MusicKit capability and `NSAppleMusicUsageDescription`. No Music User Token, developer token, or Apple Music library data is stored on Wavepoint servers.

## Android architecture

Android is a native Kotlin application using Jetpack Compose. Rewriting the shipped SwiftUI app into a cross-platform framework would add migration risk without helping the immediate provider work.

### Project shape

- Gradle Kotlin DSL with version catalog.
- Single app module and one Compose activity.
- Coroutines and `StateFlow` for session and cleanup state machines.
- Supabase Kotlin Auth for Spotify OAuth and deep-link session import.
- Local token/session storage encrypted with a key protected by Android Keystore.
- OkHttp/serialization for Spotify Web API calls.
- Spotify Android App Remote AAR for targeted playback and 15-second segments.

The Android package is `ai.mapier.swipe`. Spotify requires this package plus debug and release SHA-1 fingerprints in the Spotify Developer Dashboard. The Spotify app must be installed for App Remote playback. Wavepoint vendors and pins the official App Remote `0.8.0` AAR, records its source release and SHA-256 checksum, and retains the accompanying license notices instead of depending on an unversioned local binary.

The Supabase OAuth callback and Spotify App Remote connection are separate authorization surfaces. Supabase returns the Web API provider access/refresh tokens; App Remote uses its own registered redirect URI, package, and fingerprint connection flow and requests `app-remote-control` if the account has not already approved it. Both flows use the same Spotify client ID but must have distinct callback handling.

Supabase restores its own session but does not refresh Spotify provider credentials. Android captures `providerToken` and `providerRefreshToken`, stores them with a key protected by Android Keystore, and reuses the existing `spotify-token-refresh` Edge Function for Spotify refresh. No deprecated AndroidX Security Crypto dependency is introduced.

### Android behavior

Android ships only the Spotify branch:

- Cut Record login screen with `Spotify Premium required` disclosure.
- Supabase Spotify OAuth with the same cleanup scopes plus `user-read-private` and `app-remote-control`.
- Premium check before the deck.
- Same 50-track weighted deck, card, gestures, undo, review, chunked removal, and completion.
- Same explicit Free-account blocker and reconnect states.
- Account deletion through the existing Supabase Edge Function.

Android UI uses the established Wavepoint design tokens: paper, ink, dark surface, coral Remove, acid-lime Keep, audio blue, rounded display type, monospaced system labels, compact radii, and hard offset shadows.

## State and error handling

Provider selection, authentication, eligibility, deck loading, playback setup, review, commit, and completion remain explicit states. Provider errors map to user outcomes rather than leaking SDK language.

Required states include:

- Spotify Free/Open account;
- Spotify missing subscription scope;
- Spotify app absent or App Remote disconnected;
- Apple Music permission denied/restricted;
- Apple Music subscription absent;
- Sync Library disabled;
- Apple song unavailable for playback;
- Dumpster playlist creation/update failure;
- partial Spotify removal;
- Spotify subscription value absent/unknown or tester account not allowlisted;
- provider session changed while work is in flight.

Spotify partial commits retain only the unconfirmed remainder in review and report the committed count. Apple commits re-fetch the app-created playlist after an ambiguous write failure, calculate which staged IDs are already present, and retry only missing songs; completion reports the number newly present in the Dumpster, not the number submitted.

Changing providers cancels playback, discards unconfirmed decisions after warning when necessary, clears provider-local credentials/state, and returns to the provider picker.

## Privacy and App Review

- Update the login disclosure and App Review notes to state Spotify Premium requirements.
- Add Apple Music permission purpose copy and explain the Dumpster limitation.
- State that Apple Music library contents and cleanup decisions are not uploaded to Wavepoint-controlled servers; MusicKit still communicates with Apple's services.
- Update PrivacyInfo and public privacy text only if the implemented APIs change declared data handling or required-reason usage.
- Preserve Spotify attribution and artwork rules on both platforms.

## Verification

### iOS automated

- Spotify profile decoding and Premium/Free/Open eligibility.
- Sign-in and restore gating, including legacy missing-scope behavior.
- Provider selection and provider switching.
- Provider-neutral deck behavior remains deterministic.
- Apple authorization/subscription state mapping.
- Apple library pagination and domain mapping.
- Apple playback start/stop/cancellation behavior.
- Dumpster creation, update, deduplication, missing-playlist recovery, and truthful result copy.
- Shared review/commit state for automatic removal versus Dumpster update.
- SwiftUI state/accessibility identifiers for both provider branches.

### iOS runtime

Use the simulator's Music app/account for exploratory Apple authorization, subscription/Sync Library gates, library loading, targeted playback, 15-second stop, Dumpster creation/update, and open-in-Music handoff. Apple's current MusicKit sample explicitly does not run in Simulator, so a real device with Apple Music and Sync Library is a release gate for authorization, playback, and playlist mutation. Spotify App Remote also remains a physical-device checkpoint because the Spotify app is required.

### Android automated

- Kotlin unit tests for ranking, state transitions, Premium gate, pagination, request encoding, removal chunking, and partial failures.
- Compose UI tests for login disclosure, blocker, card actions, review, and completion.
- Gradle lint and assemble checks.

### Android runtime

Use a Play-enabled emulator for provider UI, OAuth callback, Web API loading, and review/removal. App Remote playback requires the Spotify app logged into an allowlisted Premium account; if emulator installation is unavailable, preserve that as a named physical-device checkpoint rather than claiming it passed.

## Release sequence

1. Commit this design.
2. Add and verify Spotify Premium gating on iOS.
3. Refactor the iOS cleanup domain without changing Spotify behavior.
4. Add Apple Music eligibility, library, playback, and Dumpster adapters.
5. Verify iOS and upload the next TestFlight build.
6. Scaffold Android and land auth/API behavior before UI parity.
7. Complete Compose cleanup flow and emulator verification.
8. Stop simulators/emulators, Gradle daemons, and temporary build processes after each heavy phase.

## Spotify distribution constraint

Spotify Development Mode is suitable for implementation and TestFlight/internal Android testing, not a public Spotify launch. As of July 2026 it permits at most five explicitly allowlisted users, requires the app owner to have Premium, and returns `403` for non-allowlisted accounts even if login succeeds. Spotify's published Extended Quota criteria require an established organization, a launched service, and at least 250,000 monthly active users, among other review requirements.

Therefore the public iOS binary can launch with Apple Music while Spotify is visibly marked as limited beta access until Extended Quota approval. Android can be built and distributed to the allowlisted test cohort, but public Spotify functionality cannot honestly be promised under the current quota. Before monetization or public review, Wavepoint must also review Spotify's Android SDK policy note that streaming applications may not be commercial and obtain any required approval.

## External setup

- Enable MusicKit for `ai.mapier.swipe` in Apple Developer identifiers/provisioning if automatic capability management cannot do so.
- Add Android package `ai.mapier.swipe` and the generated debug SHA-1 fingerprint to the Spotify Developer Dashboard.
- Add the Android deep-link callback to Supabase redirect allowlists if the existing wildcard does not cover it.
- Register the Android release fingerprint when a Play signing key exists.

## Non-goals

- Pretending Apple Music songs were deleted.
- Using private Apple Music endpoints.
- Adding Apple Music to Android in this version.
- Syncing cleanup decisions between devices.
- Replacing Supabase on the Spotify path.
- Rewriting the existing iOS app into React Native or another cross-platform framework.
