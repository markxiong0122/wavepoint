# Wavepoint release artifacts

App Store IPA files in this directory are signed distribution builds for `ai.mapier.swipe`.

- `Wavepoint-0.1.0-1.ipa`: initial signed archive.
- `Wavepoint-0.1.0-2.ipa`: hybrid playback and in-app account deletion release candidate.
- `Wavepoint-0.1.0-3.ipa`: automatic cleanup playback and artwork layout release candidate.
- `Wavepoint-0.1.0-4.ipa`: Spotify library removal fix uploaded to TestFlight.
- `Wavepoint-0.1.0-5.ipa`: Spotify/Apple Music provider picker, Apple Music playback, and the `Wavepoint Dumpster 🗑️` cleanup flow, uploaded to TestFlight.
- `Wavepoint-0.1.0-6.ipa`: autoplay recovery, adaptive cleanup-card layout, and game-feel haptics, uploaded to TestFlight.
- `Wavepoint-0.1.0-7.ipa`: Apple Music connection recovery, repeat Dumpster batches, and Simulator state QA, uploaded to TestFlight.
- `Wavepoint-0.1.0-8.ipa`: faster Spotify loading, selectable 10/25/50-song cleanup runs, Averia editorial accents, the local App Review demo, and the redesigned app icon, uploaded to TestFlight.

Build 8 upload was accepted by App Store Connect on July 14, 2026. Delivery `15efdf54-f96e-4362-a231-fe873d20b650` finished processing with status `VALID`.

## Current App Review notes

- Spotify cleanup requires Spotify Premium. Development-mode Spotify accounts must be allowlisted by the app owner.
- Apple Music cleanup requires Media & Apple Music permission, an active Apple Music subscription, and Sync Library.
- Wavepoint cannot delete songs from an Apple Music library. It creates or updates `Wavepoint Dumpster 🗑️`; the user must open Music and choose **Delete from Library** for each song. **Remove from Playlist** alone is not presented as deletion.
- Apple Music library data remains on device and does not use Wavepoint's Supabase backend. Supabase account deletion is shown only to Spotify users.
- Review Apple Music authorization, playback, and Dumpster writes on a physical iPhone. Simulator MusicKit results are not accepted as release proof.
- Reviewers can choose **Try a Demo Cleanup** to exercise the full core flow with fictional tracks and bundled audio; it does not connect to or change a music library.

Verify a file before upload with:

```sh
shasum -a 256 -c SHA256SUMS
```

Public releases must also complete [`docs/release-checklist.md`](../docs/release-checklist.md). Monitoring procedures and stop-ship gates live in [`docs/release-operations.md`](../docs/release-operations.md).
