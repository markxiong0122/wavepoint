# Public release checklist

## External approvals

- [ ] Spotify app is approved for Extended Quota Mode; Development Mode is limited to five users.
- [ ] Spotify owner Premium subscription is active until Extended Quota behavior is confirmed.
- [ ] Apple App Store agreements, tax, and banking are current.
- [ ] Google Play developer account, Play App Signing, release SHA-1, and store listing are complete.
- [ ] Android upload-key signing is configured outside the repository and the resulting bundle signature is verified.

## Configuration

- [ ] PostHog project token and host are added to iOS and Android build configuration.
- [ ] `GoogleService-Info.plist` is added at `ios/Wavepoint/Resources/`.
- [ ] `google-services.json` is added at `android/app/`.
- [ ] Both Firebase apps use package/bundle ID `ai.mapier.swipe`.
- [ ] Firebase Analytics remains disabled/not linked into the binaries.
- [ ] Crashlytics symbol upload succeeds for the release build.
- [ ] Supabase Edge Functions are deployed and emit request ID/function/status only.

## Compliance

- [x] Spotify scopes exclude `user-read-recently-played`.
- [ ] Analytics event inspection matches `docs/analytics-contract.md`.
- [x] Hosted privacy and support pages are live.
- [ ] App Store privacy answers match `APP_STORE.md` and the generated privacy report.
- [ ] Google Play Data Safety discloses anonymous app interactions, device identifiers, and crash diagnostics; no tracking or ads.
- [ ] Privacy policy and support links open from Account on iOS and Android.
- [ ] Account deletion and Spotify sign-out/revocation instructions work.
- [x] App is not categorized or marketed to children; App Store Connect calculated a 12+ rating.

## Quality

- [x] iOS unit tests and signed App Store archive pass.
- [ ] Android unit tests, lint, and release bundle pass.
- [ ] Deno Edge Function tests and formatting pass.
- [ ] Spotify Premium physical-device flow passes.
- [ ] Spotify Free blocker explains the requirement.
- [x] Public demo completes 10-, 25-, and 50-song routes with local autoplay, swipe, undo, review, completion, another run, and exit.
- [x] Public demo never opens a music app, displays a provider destination, or changes a provider library.
- [ ] Apple Music physical-device authorization, playback, and Dumpster flow pass.
- [ ] A second Apple Music batch appends only new tracks and still succeeds when an older Dumpster track is unavailable.
- [ ] Release archive contains no DEBUG-only `WavepointAppleMusicDemo` launch-argument harness; the separately labeled public review demo remains present and functional.
- [ ] One symbolicated test crash arrives from each platform.
- [ ] PostHog receives the allowed funnel without music data.

## Store release

- [x] Version/build numbers are incremented (`0.1.0 (8)`).
- [x] Six current 6.9-inch screenshots and listing copy reflect both providers, the batch picker, and the public demo; all screenshot assets processed successfully in App Store Connect.
- [x] Free pricing and all 175 App Store territories are configured; EU storefronts remain dependent on Mapier trader-status verification.
- [ ] App Review notes lead with **Try a Demo Cleanup** and state that it uses fictional local content with no account or provider changes.
- [ ] A dedicated allowlisted disposable Spotify Premium account is supplied only if App Review specifically requests the live limited-beta integration.
- [ ] App Review notes explain the Apple Music Dumpster limitation.
- [x] Release notes, checksum, archive/export, and rollback build are recorded.
- [ ] First-week monitoring owner and daily check time are assigned.
