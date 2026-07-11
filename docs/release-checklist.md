# Public release checklist

## External approvals

- [ ] Spotify app is approved for Extended Quota Mode; Development Mode is limited to five users.
- [ ] Spotify owner Premium subscription is active until Extended Quota behavior is confirmed.
- [ ] Apple App Store agreements, tax, and banking are current.
- [ ] Google Play developer account, Play App Signing, release SHA-1, and store listing are complete.

## Configuration

- [ ] PostHog project token and host are added to iOS and Android build configuration.
- [ ] `GoogleService-Info.plist` is added at `ios/Wavepoint/Resources/`.
- [ ] `google-services.json` is added at `android/app/`.
- [ ] Both Firebase apps use package/bundle ID `ai.mapier.swipe`.
- [ ] Firebase Analytics remains disabled/not linked into the binaries.
- [ ] Crashlytics symbol upload succeeds for the release build.
- [ ] Supabase Edge Functions are deployed and emit request ID/function/status only.

## Compliance

- [ ] Spotify scopes exclude `user-read-recently-played`.
- [ ] Analytics event inspection matches `docs/analytics-contract.md`.
- [ ] Hosted privacy and support pages are live.
- [ ] App Store privacy answers match `APP_STORE.md` and the generated privacy report.
- [ ] Google Play Data Safety discloses anonymous app interactions, device identifiers, and crash diagnostics; no tracking or ads.
- [ ] Privacy policy and support links open from Account on iOS and Android.
- [ ] Account deletion and Spotify sign-out/revocation instructions work.
- [ ] App is not categorized or marketed to children.

## Quality

- [ ] iOS unit tests and unsigned archive pass.
- [ ] Android unit tests, lint, and release bundle pass.
- [ ] Deno Edge Function tests and formatting pass.
- [ ] Spotify Premium physical-device flow passes.
- [ ] Spotify Free blocker explains the requirement.
- [ ] Apple Music physical-device authorization, playback, and Dumpster flow pass.
- [ ] One symbolicated test crash arrives from each platform.
- [ ] PostHog receives the allowed funnel without music data.

## Store release

- [ ] Version/build numbers are incremented.
- [ ] Screenshots and copy reflect both providers and current UI.
- [ ] App Review receives an allowlisted disposable Spotify Premium account while required.
- [ ] App Review notes explain the Apple Music Dumpster limitation.
- [ ] Release notes, checksum, archive/export, and rollback build are recorded.
- [ ] First-week monitoring owner and daily check time are assigned.
