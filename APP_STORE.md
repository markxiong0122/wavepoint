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

Hear an available preview, see when a track was saved, and make one simple decision: keep it or stage it for removal. Old songs and tracks outside your recent rotation are more likely to surface, so the forgotten corners of your library get attention first.

Nothing is removed while you swipe. Wavepoint keeps every removal staged on your iPhone until you review the exact list and confirm the batch.

Features:

- Weighted cleanup decks from your Spotify Liked Songs
- Fast swipe, button, and undo controls
- Available 15-second previews and Open in Spotify fallback
- Safe removal review before Spotify changes
- Secure Spotify tokens in iOS Keychain
- No ads, tracking, or analytics

Spotify account required. Preview availability is determined by Spotify.

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

## Screenshot plan

Capture on a 6.3-inch iPhone simulator or device:

1. Cut Record login screen.
2. Track card with preview control.
3. Left-swipe Remove stamp.
4. Right-swipe Keep stamp.
5. Staged-removal review.
6. Completion summary.
