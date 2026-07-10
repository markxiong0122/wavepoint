# Wavepoint release artifacts

App Store IPA files in this directory are signed distribution builds for `ai.mapier.swipe`.

- `Wavepoint-0.1.0-1.ipa`: initial signed archive.
- `Wavepoint-0.1.0-2.ipa`: hybrid playback and in-app account deletion release candidate.
- `Wavepoint-0.1.0-3.ipa`: automatic cleanup playback and artwork layout release candidate.
- `Wavepoint-0.1.0-4.ipa`: Spotify library removal fix uploaded to TestFlight.

Verify a file before upload with:

```sh
shasum -a 256 -c SHA256SUMS
```
