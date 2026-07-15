# Wavepoint App Store Metadata

## Listing

- **Name:** Mapier Swipe
- **Subtitle:** Swipe through your music
- **Primary category:** Music
- **Secondary category:** Utilities
- **Bundle ID:** `ai.mapier.swipe`
- **SKU:** `wavepoint`
- **Version:** `0.1.0`
- **Price:** Free
- **Availability:** All 175 App Store territories; EU storefronts remain blocked until Mapier completes trader-status verification.
- **Age rating:** 12+ (infrequent or mild music-related profanity, mature themes, and alcohol/tobacco/drug references)
- **Copyright:** 2026 Mapier Labs Inc.
- **Privacy policy:** `https://markxiong0122.github.io/wavepoint/privacy.html`
- **Support:** `https://markxiong0122.github.io/wavepoint/support.html`

## Promotional text

Finally deal with the songs buried in your Spotify or Apple Music library—fast, safely, and one swipe at a time.

## Description

Mapier Swipe presents Wavepoint, a fast way to turn an overloaded music library into a quick cleanup session. Connect Spotify, choose Apple Music, or try the built-in fictional demo, then work through one focused deck instead of scrolling an endless list.

Hear a 15-second segment, see when a track was saved, and make one simple decision: keep it or stage it for cleanup. Older saved songs receive more weight so the forgotten corners of your library get attention first.

Nothing changes while you swipe. Wavepoint keeps every removal staged on your iPhone until you review the exact list and confirm the batch. Spotify can remove the confirmed songs directly. Apple Music places them in a private **Wavepoint Dumpster** playlist so you can delete them from your library in Music; Apple does not allow Wavepoint to perform that final deletion.

Features:

- Weighted cleanup decks from Spotify Liked Songs or your Apple Music library
- Fast swipe, button, and undo controls
- Automatic listening segments through Spotify or Apple Music
- Safe review before Spotify changes or an Apple Music Dumpster update
- Secure Spotify tokens in iOS Keychain
- Anonymous, music-data-free reliability analytics
- Built-in fictional demo with local audio and no account or library changes

Spotify is currently a limited beta requiring an approved tester account, Premium, and the Spotify iOS app for App Remote playback. Apple Music requires Media & Apple Music permission, Sync Library, and an active subscription. Playback and catalog availability are determined by the selected provider.

## Keywords

`spotify,apple music,liked songs,music,cleaner,library,swipe,organize`

## Review notes

No account is required to review Wavepoint's complete core flow. From the first provider screen, tap **Try a Demo Cleanup**. The demo is clearly labeled, uses fictional songs and bundled local audio, and makes no provider request or change to Spotify, Apple Music, or the device music library.

To exercise the full flow safely:

1. Tap **Try a Demo Cleanup**.
2. Choose **Needle Drop · 10 songs**.
3. Swipe one track left and one right.
4. Use Undo once.
5. Tap Review.
6. Confirm the staged demo cuts. The completion screen reiterates that the songs were fictional and no library changed.

Spotify uses OAuth through Supabase and remains a clearly labeled limited beta while Spotify Development Mode restricts access to allowlisted testers. The built-in demo exists so App Review never needs credentials for a personal or third-party music account. If App Review specifically requires the live Spotify integration, provide a dedicated allowlisted disposable Premium account in App Store Connect; never provide a personal account.

The app requests `user-library-read`, `user-library-modify`, `user-read-private`, `user-read-email`, and `app-remote-control`. It does not request recent-listening access or upload the user's library to Wavepoint, PostHog, or Firebase.

After the cleanup deck loads, Wavepoint automatically asks Spotify to play the first selected track. Spotify may open once to authorize or wake playback, then returns to the matching Wavepoint card. Later cards start automatically while the App Remote connection is active. If setup fails, the reviewer can retry or continue with explicit preview controls.

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

The current `en-US` set was captured on an iPhone 17 Pro Max at 1320 × 2868 and uploaded to App Store Connect:

1. `01-provider-picker.png` — Spotify, Apple Music, and local demo choices.
2. `02-batch-picker.png` — 10-, 25-, and 50-song cleanup modes.
3. `03-track-card.png` — active fictional track card and local preview.
4. `04-cut-staged.png` — staged cut with progress, Review, and Undo visible.
5. `05-review.png` — safe staged-removal review.
6. `06-complete.png` — explicit no-library-change demo completion.
