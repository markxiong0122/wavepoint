# Wavepoint App Store Metadata

## Listing

- **Name:** Wavepoint
- **Subtitle:** Clean up your Liked Songs
- **Primary category:** Music
- **Secondary category:** Utilities
- **Bundle ID:** `ai.mapier.swipe`
- **SKU:** `wavepoint-ios-001`
- **Version:** `0.1.0`
- **Copyright:** 2026 Mapier Labs Inc.
- **Privacy policy:** `https://markxiong0122.github.io/wavepoint/privacy.html`
- **Support:** `https://github.com/markxiong0122/wavepoint/issues`

## Promotional text

Finally clear the songs buried in your Spotify Liked Songs—fast, safely, and one swipe at a time.

## Description

Wavepoint turns an overloaded Spotify library into a quick cleanup session.

Hear a 15-second segment, see when a track was saved, and make one simple decision: keep it or stage it for removal. After the deck loads, Wavepoint may open Spotify automatically with the first cleanup track. It then plays each following card through the active Spotify connection. Old songs and tracks outside your recent rotation are more likely to surface, so the forgotten corners of your library get attention first.

Nothing is removed while you swipe. Wavepoint keeps every removal staged on your iPhone until you review the exact list and confirm the batch.

Features:

- Weighted cleanup decks from your Spotify Liked Songs
- Fast swipe, button, and undo controls
- Automatic 15-second listening segments through Spotify App Remote
- Safe removal review before Spotify changes
- Secure Spotify tokens in iOS Keychain
- No ads, tracking, or analytics

Spotify account required. The Spotify iOS app must be installed for App Remote playback. Spotify playback eligibility and preview availability are determined by Spotify.

## Keywords

`spotify,liked songs,music,cleaner,library,swipe,playlist,organize`

## Review notes

Wavepoint uses Spotify OAuth through Supabase. The reviewer account must be allowlisted in the Spotify developer app while the integration remains in Spotify Development Mode. Provide App Review with credentials for a dedicated allowlisted Spotify test account; do not provide a personal account.

To exercise the destructive flow safely:

1. Sign in with the supplied Spotify test account.
2. Swipe one track left and one right.
3. Use Undo once.
4. Tap Review.
5. The review screen confirms that no change has happened yet.
6. Confirm the deliberately small removal batch.

The app requests `user-library-read`, `user-library-modify`, `user-read-recently-played`, and `user-read-email`. It does not collect analytics or upload the user's library to a Wavepoint database.

It also requests `app-remote-control`. After the cleanup deck loads, Wavepoint automatically asks Spotify to play the first selected track. Spotify may open once to authorize or wake playback, then returns to the matching Wavepoint card. Later cards start automatically while the App Remote connection is active. If setup fails, the reviewer can retry or continue with explicit preview controls.

Account deletion is available under **Account → Delete Account** and requires a second destructive confirmation. It deletes the Supabase Auth user and local Wavepoint credentials. It does not delete the Spotify account or songs. Use only a disposable review account when testing deletion.

## App privacy answers

- **Does this app or its third-party partners collect data?** Yes.
- **Contact Info → Name:** Collected, linked to the user, App Functionality. Supabase Auth receives the Spotify display name as provider metadata.
- **Contact Info → Email Address:** Collected, linked to the user, App Functionality.
- **Identifiers → User ID:** Collected, linked to the user, App Functionality. This includes Supabase and Spotify account identifiers.
- **User Content → Photos or Videos:** Collected, linked to the user, App Functionality. Supabase Auth may retain the Spotify profile image URL supplied as provider metadata; Wavepoint does not display or otherwise use it.
- **Tracking:** No.
- **Advertising, marketing, analytics, or data brokerage:** No.
- **Privacy Choices URL:** `https://markxiong0122.github.io/wavepoint/privacy.html`

Spotify library contents, recent listening history, cleanup decisions, and playback state are processed for the requested feature but are not retained on Wavepoint servers. Spotify credentials are retained in the iOS Keychain, not in a Wavepoint database.

## Screenshots

Capture on a 6.9-inch iPhone simulator or device. The first required screenshot is ready at `app-store/screenshots/6.9-inch/01-login.png` (1320 × 2868):

1. Cut Record login screen. (Ready)
2. Track card with 15-second listening control.
3. Left-swipe Remove stamp.
4. Right-swipe Keep stamp.
5. Staged-removal review.
6. Completion summary.
