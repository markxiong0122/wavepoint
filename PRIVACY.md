# Wavepoint Privacy Policy

Effective date: July 9, 2026

Wavepoint is an iPhone utility that helps you review and remove tracks from your Spotify Liked Songs library.

## Data Wavepoint accesses

When you choose Continue with Spotify, Spotify asks you to authorize access to your account. Wavepoint requests permission to read your saved music and recent listening history, remove items from your library only after you confirm a removal batch, and control Spotify playback only after you tap a Spotify listening control.

Wavepoint receives Spotify access and refresh tokens needed to make those requests. Tokens are stored in the iOS Keychain on your device. Your cleanup decisions remain on your device and are not uploaded to a Wavepoint database.

Supabase Auth stores a Wavepoint authentication record so you can remain signed in. That record includes a Supabase user ID and Spotify-provided account metadata such as your Spotify account ID, email address, display name, and profile image URL when Spotify supplies them. Wavepoint uses this information only for authentication and account security.

## Data collection and tracking

Wavepoint does not sell personal data, use advertising SDKs, track you across apps or websites, or collect product analytics in this version. Wavepoint does not store your Spotify library, listening history, cleanup decisions, or playback history in a Wavepoint database.

Spotify and Supabase process authentication and API requests under their own terms and privacy policies. Their infrastructure may process standard request information such as IP address and request time for security and service operation. Album artwork and available audio preview clips are loaded from Spotify-provided URLs. If a direct preview is unavailable and you explicitly tap the Spotify playback control, Spotify may open to authorize or play the selected track.

## Library changes

Swiping a song does not immediately change your Spotify library. Songs marked for removal are staged on your device. Wavepoint sends a removal request to Spotify only after you review the staged list and confirm the exact batch count.

## Retention and deletion

Supabase retains your Wavepoint authentication record until you delete the account. Wavepoint retains Spotify authorization tokens in the iOS Keychain so you can remain signed in.

In the app, open **Account**:

- **Sign Out** clears Wavepoint's locally stored Spotify tokens and signs out of Supabase.
- **Delete Account** permanently deletes your Supabase authentication record and clears Wavepoint's local Spotify credentials after a second confirmation.

Deleting your Wavepoint account does not delete your Spotify account or songs, and it does not automatically revoke Spotify's authorization grant. You can separately revoke Wavepoint from your Spotify account's Apps page. Because iOS Keychain items can outlive an app installation, use Sign Out or Delete Account before uninstalling if you want credentials cleared immediately.

## Children

Wavepoint is not directed to children and does not knowingly collect personal information from children.

## Changes

If Wavepoint's data practices change, this policy will be updated before the changed version is released.

## Contact

For privacy or support questions, open an issue at <https://github.com/markxiong0122/wavepoint/issues>.
