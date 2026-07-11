# Wavepoint App Store Metadata

## Listing

- **Name:** Wavepoint
- **Subtitle:** Swipe through your music
- **Primary category:** Music
- **Secondary category:** Utilities
- **Bundle ID:** `ai.mapier.swipe`
- **SKU:** `wavepoint-ios-001`
- **Version:** `0.1.0`
- **Copyright:** 2026 Mapier Labs Inc.
- **Privacy policy:** `https://markxiong0122.github.io/wavepoint/privacy.html`
- **Support:** `https://markxiong0122.github.io/wavepoint/support.html`

## Promotional text

Finally deal with the songs buried in your Spotify or Apple Music library—fast, safely, and one swipe at a time.

## Description

Wavepoint turns an overloaded music library into a quick cleanup session. Connect Spotify or choose Apple Music, then work through one focused deck instead of scrolling an endless list.

Hear a 15-second segment, see when a track was saved, and make one simple decision: keep it or stage it for cleanup. Older saved songs receive more weight so the forgotten corners of your library get attention first.

Nothing changes while you swipe. Wavepoint keeps every removal staged on your iPhone until you review the exact list and confirm the batch. Spotify can remove the confirmed songs directly. Apple Music places them in a private **Wavepoint Dumpster** playlist so you can delete them from your library in Music; Apple does not allow Wavepoint to perform that final deletion.

Features:

- Weighted cleanup decks from Spotify Liked Songs or your Apple Music library
- Fast swipe, button, and undo controls
- Automatic listening segments through Spotify or Apple Music
- Safe review before Spotify changes or an Apple Music Dumpster update
- Secure Spotify tokens in iOS Keychain
- Anonymous, music-data-free reliability analytics

Spotify requires an eligible account and the Spotify iOS app for App Remote playback. Apple Music requires Media & Apple Music permission, Sync Library, and an active subscription. Playback and catalog availability are determined by the selected provider.

## Keywords

`spotify,apple music,liked songs,music,cleaner,library,swipe,organize`

## Review notes

Wavepoint uses Spotify OAuth through Supabase. The reviewer account must be allowlisted in the Spotify developer app while the integration remains in Spotify Development Mode. Provide App Review with credentials for a dedicated allowlisted Spotify test account; do not provide a personal account.

To exercise the destructive flow safely:

1. Sign in with the supplied Spotify test account.
2. Swipe one track left and one right.
3. Use Undo once.
4. Tap Review.
5. The review screen confirms that no change has happened yet.
6. Confirm the deliberately small removal batch.

The app requests `user-library-read`, `user-library-modify`, `user-read-private`, `user-read-email`, and `app-remote-control`. It does not request recent-listening access or upload the user's library to Wavepoint, PostHog, or Firebase.

It also requests `app-remote-control`. After the cleanup deck loads, Wavepoint automatically asks Spotify to play the first selected track. Spotify may open once to authorize or wake playback, then returns to the matching Wavepoint card. Later cards start automatically while the App Remote connection is active. If setup fails, the reviewer can retry or continue with explicit preview controls.

Account deletion is available under **Account → Delete Account** and requires a second destructive confirmation. It deletes the Supabase Auth user and local Wavepoint credentials. It does not delete the Spotify account or songs. Use only a disposable review account when testing deletion.

Apple Music does not create a Wavepoint server account. A reviewer can choose Apple Music from the provider picker, grant access, stage songs, and confirm the batch. Wavepoint creates or updates **Wavepoint Dumpster 🗑️**; the review screen and completion screen explain that each song must still be deleted from the library inside Music.

## App privacy answers

- **Does this app or its third-party partners collect data?** Yes.
- **Contact Info → Name:** Collected, linked to the user, App Functionality. Supabase Auth receives the Spotify display name as provider metadata.
- **Contact Info → Email Address:** Collected, linked to the user, App Functionality.
- **Identifiers → User ID:** Collected, linked to the user, App Functionality. This includes Supabase and Spotify account identifiers.
- **User Content → Photos or Videos:** Collected, linked to the user, App Functionality. Supabase Auth may retain the Spotify profile image URL supplied as provider metadata; Wavepoint does not display or otherwise use it.
- **Identifiers → Device ID:** Collected, not linked to the user, Analytics. PostHog and Crashlytics use random installation identifiers.
- **Usage Data → Product Interaction:** Collected, not linked to the user, Analytics. Only generic Wavepoint funnel events are recorded.
- **Diagnostics → Crash Data:** Collected, not linked to the user, Analytics. Crashlytics receives crash traces and relevant device/app state.
- **Tracking:** No.
- **Advertising, marketing, or data brokerage:** No.
- **Privacy Choices URL:** `https://markxiong0122.github.io/wavepoint/privacy.html`

Music library contents, cleanup decisions, and playback state are processed for the requested feature but are not retained on Wavepoint servers or included in analytics. Spotify credentials are retained in the iOS Keychain, not in product analytics.

## Screenshots

Capture on a 6.9-inch iPhone simulator or device. The first required screenshot is ready at `app-store/screenshots/6.9-inch/01-login.png` (1320 × 2868):

1. Cut Record login screen. (Ready)
2. Track card with 15-second listening control.
3. Left-swipe Remove stamp.
4. Right-swipe Keep stamp.
5. Staged-removal review.
6. Completion summary.
