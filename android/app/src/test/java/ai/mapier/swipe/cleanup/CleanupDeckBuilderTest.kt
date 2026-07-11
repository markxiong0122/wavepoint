package ai.mapier.swipe.cleanup

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CleanupDeckBuilderTest {
  private val now = Instant.parse("2026-01-01T00:00:00Z")

  @Test
  fun olderSongsReceiveHigherWeightsWithoutUsingListeningHistory() {
    val builder = CleanupDeckBuilder(referenceDate = now)
    val old = track("old", "2018-01-01T00:00:00Z")
    val new = track("new", "2025-12-01T00:00:00Z")

    val oldWeight = builder.selectionWeight(old)
    val newWeight = builder.selectionWeight(new)

    assertTrue(oldWeight > newWeight)
  }

  @Test
  fun seedProducesARepeatableWeightedShuffle() {
    val tracks = (0 until 12).map { index ->
      track(index.toString().padStart(3, '0'), Instant.EPOCH.plusSeconds(index * 1_000L))
    }
    val builder = CleanupDeckBuilder(referenceDate = now)

    val first = builder.build(tracks, seed = 42)
    val second = builder.build(tracks, seed = 42)
    val different = builder.build(tracks, seed = 7)

    assertEquals(first.map { it.id }, second.map { it.id })
    assertNotEquals(first.map { it.id }, different.map { it.id })
    assertEquals(tracks.map { it.id }.toSet(), first.map { it.id }.toSet())
  }

  @Test
  fun deckIsCappedAtFiftySongs() {
    val tracks = (0 until 75).map { track(it.toString(), Instant.EPOCH) }

    val deck = CleanupDeckBuilder().build(tracks, seed = 1)

    assertEquals(50, deck.size)
  }

  @Test
  fun missingAddedDateUsesNeutralWeight() {
    val unknown = track("unknown", addedAt = null)
    val builder = CleanupDeckBuilder(referenceDate = now)

    assertEquals(1.0, builder.selectionWeight(unknown), 0.0001)
  }

  private fun track(id: String, addedAt: String): LibraryTrack =
    track(id, Instant.parse(addedAt))

  private fun track(id: String, addedAt: Instant?): LibraryTrack = LibraryTrack(
    id = id,
    playbackId = "spotify:track:$id",
    commitId = "spotify:track:$id",
    title = "Track $id",
    artistNames = listOf("Artist"),
    artworkUrl = null,
    destinationUrl = "https://open.spotify.com/track/$id",
    durationMilliseconds = 180_000,
    addedAt = addedAt,
  )
}
