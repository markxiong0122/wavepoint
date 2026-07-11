package ai.mapier.swipe.spotify

import ai.mapier.swipe.cleanup.LibraryTrack
import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

enum class SpotifyAccountEligibility {
  PREMIUM,
  FREE,
  UNVERIFIABLE,
}

interface SpotifyAccountEligibilityChecker {
  suspend fun fetchAccountEligibility(): SpotifyAccountEligibility
}

enum class SpotifyWebApiErrorKind {
  ACCOUNT_ELIGIBILITY_FORBIDDEN,
  AUTHORIZATION_EXPIRED,
  INVALID_DATA,
  RATE_LIMITED,
  HTTP_STATUS,
  PARTIAL_REMOVAL,
}

class SpotifyWebApiException(
  val kind: SpotifyWebApiErrorKind,
  val statusCode: Int? = null,
  val committedCount: Int? = null,
  val remainingCount: Int? = null,
  cause: Throwable? = null,
) : Exception(message(kind, statusCode, committedCount, remainingCount), cause) {
  private companion object {
    fun message(
      kind: SpotifyWebApiErrorKind,
      statusCode: Int?,
      committedCount: Int?,
      remainingCount: Int?,
    ): String = when (kind) {
      SpotifyWebApiErrorKind.ACCOUNT_ELIGIBILITY_FORBIDDEN ->
        "Spotify could not verify this account. Reconnect or ask the app owner to add it as a tester."
      SpotifyWebApiErrorKind.AUTHORIZATION_EXPIRED ->
        "Your Spotify connection expired. Please reconnect."
      SpotifyWebApiErrorKind.INVALID_DATA ->
        "Spotify returned an unreadable response. Please try again."
      SpotifyWebApiErrorKind.RATE_LIMITED ->
        "Spotify is receiving too many requests. Please wait and retry."
      SpotifyWebApiErrorKind.HTTP_STATUS ->
        "Spotify could not complete the request (${statusCode ?: "unknown"})."
      SpotifyWebApiErrorKind.PARTIAL_REMOVAL ->
        "Removed ${committedCount ?: 0} songs, but ${remainingCount ?: 0} still need to be retried."
    }
  }
}

@Serializable
internal data class CurrentUserProfile(val product: String? = null)

@Serializable
internal data class SavedTracksPage(
  val items: List<SavedTrackItem>,
  val next: String? = null,
)

@Serializable
internal data class SavedTrackItem(
  @SerialName("added_at") val addedAt: String,
  val track: TrackPayload,
) {
  fun libraryTrack(): LibraryTrack? {
    val id = track.id ?: return null
    val destination = track.externalUrls.spotify ?: return null
    val added = runCatching { Instant.parse(addedAt) }.getOrNull() ?: return null
    return LibraryTrack(
      id = id,
      playbackId = track.uri,
      commitId = track.uri,
      title = track.name,
      artistNames = track.artists.map(ArtistPayload::name),
      artworkUrl = track.album.images.firstOrNull()?.url,
      previewUrl = track.previewUrl,
      destinationUrl = destination,
      durationMilliseconds = track.durationMilliseconds,
      addedAt = added,
    )
  }
}

@Serializable
internal data class TrackPayload(
  val id: String? = null,
  val uri: String,
  val name: String,
  val artists: List<ArtistPayload>,
  val album: AlbumPayload,
  @SerialName("preview_url") val previewUrl: String? = null,
  @SerialName("external_urls") val externalUrls: ExternalUrls,
  @SerialName("duration_ms") val durationMilliseconds: Int,
)

@Serializable
internal data class ArtistPayload(val name: String)

@Serializable
internal data class AlbumPayload(val images: List<ImagePayload>)

@Serializable
internal data class ImagePayload(val url: String)

@Serializable
internal data class ExternalUrls(val spotify: String? = null)
