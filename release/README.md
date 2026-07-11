# Wavepoint release artifacts

App Store IPA files in this directory are signed distribution builds for `ai.mapier.swipe`.

- `Wavepoint-0.1.0-1.ipa`: initial signed archive.
- `Wavepoint-0.1.0-2.ipa`: hybrid playback and in-app account deletion release candidate.
- `Wavepoint-0.1.0-3.ipa`: automatic cleanup playback and artwork layout release candidate.
- `Wavepoint-0.1.0-4.ipa`: Spotify library removal fix uploaded to TestFlight.
- `Wavepoint-0.1.0-5.ipa`: Spotify/Apple Music provider picker, Apple Music playback, and the `Wavepoint Dumpster 🗑️` cleanup flow, uploaded to TestFlight.
- `Wavepoint-0.1.0-6.ipa`: autoplay recovery, adaptive cleanup-card layout, and game-feel haptics, uploaded to TestFlight.

## Current App Review notes

- Spotify cleanup requires Spotify Premium. Development-mode Spotify accounts must be allowlisted by the app owner.
- Apple Music cleanup requires Media & Apple Music permission, an active Apple Music subscription, and Sync Library.
- Wavepoint cannot delete songs from an Apple Music library. It creates or updates `Wavepoint Dumpster 🗑️`; the user must open Music and choose **Delete from Library** for each song. **Remove from Playlist** alone is not presented as deletion.
- Apple Music library data remains on device and does not use Wavepoint's Supabase backend. Supabase account deletion is shown only to Spotify users.
- Review Apple Music authorization, playback, and Dumpster writes on a physical iPhone. Simulator MusicKit results are not accepted as release proof.

Verify a file before upload with:

```sh
shasum -a 256 -c SHA256SUMS
```
