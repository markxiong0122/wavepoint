package ai.mapier.swipe.cleanup

import java.time.Instant

data class LibraryTrack(
  val id: String,
  val playbackId: String,
  val commitId: String,
  val title: String,
  val artistNames: List<String>,
  val artworkUrl: String?,
  val previewUrl: String? = null,
  val destinationUrl: String?,
  val durationMilliseconds: Int,
  val addedAt: Instant?,
) {
  val artistLine: String
    get() = artistNames.joinToString(", ")
}
