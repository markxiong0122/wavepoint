# Wavepoint Privacy Policy

Effective date: July 10, 2026

Wavepoint helps you review buried songs in Spotify or Apple Music and safely stage cleanup choices before anything changes.

## Music data

For Spotify, Wavepoint requests access to read saved music, remove items only after you confirm a batch, read the account subscription status, and control playback during cleanup. Spotify access and refresh tokens are stored in the device's secure credential storage. Supabase Auth retains a Wavepoint authentication record and Spotify-provided identity metadata used for login and account security.

For Apple Music, MusicKit reads the library and plays songs on the device. Confirmed choices create or update `Wavepoint Dumpster 🗑️` in the user's Apple Music account; Wavepoint cannot directly delete songs from the Apple Music library. Apple Music library data is not sent to Wavepoint's Supabase backend.

Wavepoint does not upload track names, track identifiers, artists, artwork, listening history, library size, playback history, saved dates, or individual Keep/Remove choices to product analytics or crash reporting services.

## Product analytics and diagnostics

Wavepoint uses PostHog for anonymous product analytics. It records a small set of Wavepoint flow events such as opening the app, connecting a music service, loading the cleanup deck, making a first decision, opening review, and completing or abandoning a session. Event properties are limited to the provider family and a coarse error category. PostHog receives an anonymous installation identifier and standard app/device information needed to provide analytics. Wavepoint does not identify PostHog users with a name, email, Spotify ID, Supabase ID, or Apple Music account.

Wavepoint uses Firebase Crashlytics for stability monitoring. Crashlytics may collect crash stack traces, relevant application state, app version, device and operating-system information, and random installation/session identifiers. Developer-recorded non-fatal incidents contain only a fixed category such as authorization, eligibility, library loading, playback, or commit. Google states that Crashlytics crash data and associated identifiers are retained for 90 days before removal begins.

Wavepoint does not use advertising SDKs, sell personal data, or track people across other companies' apps or websites. PostHog session replay, UI autocapture, person profiles, surveys, and feature flags are disabled. Firebase Analytics is not included.

## Service operation

Spotify, Apple, Supabase, PostHog, and Google process data under their own terms and privacy policies. Their infrastructure may process standard network information, including IP address and request time. Wavepoint's Supabase Edge Functions log only a random request ID, function name, and response status. Authorization headers, provider tokens, user IDs, request bodies, and music data are not written to Wavepoint's operational logs.

## Library safety

Swiping never immediately changes a library. Spotify removals are staged locally and sent only after the user reviews and confirms the batch. Apple Music choices are staged locally and then added to the Dumpster playlist after confirmation; the user completes any library deletion in Music.

## Retention and deletion

Supabase retains a Spotify user's Wavepoint authentication record until the user deletes the account. Spotify credentials remain in secure local storage until sign-out or account deletion. Apple Music does not create a Wavepoint server account.

In the app, open **Account**:

- **Sign Out** clears locally stored Spotify credentials and signs out of Supabase.
- **Delete Account** permanently deletes the Supabase authentication record and clears local Spotify credentials after a second confirmation.

Deleting a Wavepoint account does not delete the Spotify account or songs and does not automatically revoke Spotify's authorization grant. The grant can be revoked separately from Spotify's Apps page. Analytics and diagnostics are retained according to the applicable PostHog project settings and Crashlytics retention described above. Privacy deletion requests can be submitted through Wavepoint Support.

## Children

Wavepoint is not directed to children and does not knowingly collect personal information from children.

## Contact

For privacy or support questions, visit <https://markxiong0122.github.io/wavepoint/support.html>.
