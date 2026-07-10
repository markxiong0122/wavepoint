package ai.mapier.swipe.cleanup

import java.time.Duration
import java.time.Instant
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min

class CleanupDeckBuilder(
  private val maximumTrackCount: Int = 50,
  private val referenceDate: Instant = Instant.now(),
) {
  fun build(
    tracks: List<LibraryTrack>,
    recentTrackIds: Set<String>,
    seed: Long = kotlin.random.Random.nextLong(),
  ): List<LibraryTrack> {
    val random = SplitMix64(seed)
    return tracks
      .map { track ->
        val randomValue = max(random.nextDouble(), Double.MIN_VALUE)
        val weight = selectionWeight(track, recentTrackIds)
        WeightedTrack(track, ln(randomValue) / weight)
      }
      .sortedWith(
        compareByDescending<WeightedTrack> { it.priority }
          .thenBy { it.track.id },
      )
      .take(maximumTrackCount.coerceAtLeast(0))
      .map { it.track }
  }

  fun selectionWeight(
    track: LibraryTrack,
    recentTrackIds: Set<String>,
  ): Double {
    val ageInYears = track.addedAt?.let { addedAt ->
      max(0.0, Duration.between(addedAt, referenceDate).seconds / SECONDS_PER_YEAR)
    } ?: 0.0
    val ageWeight = 1 + min(ageInYears, 12.0)
    val rotationWeight = if (track.id in recentTrackIds) 0.2 else 1.0
    return ageWeight * rotationWeight
  }

  private data class WeightedTrack(
    val track: LibraryTrack,
    val priority: Double,
  )

  private class SplitMix64(seed: Long) {
    private var state = seed.toULong()

    fun nextDouble(): Double {
      val value = next() shr 11
      return value.toDouble() / (1UL shl 53).toDouble()
    }

    private fun next(): ULong {
      state += 0x9E3779B97F4A7C15UL
      var value = state
      value = (value xor (value shr 30)) * 0xBF58476D1CE4E5B9UL
      value = (value xor (value shr 27)) * 0x94D049BB133111EBUL
      return value xor (value shr 31)
    }
  }

  private companion object {
    const val SECONDS_PER_YEAR = 365.25 * 24 * 60 * 60
  }
}
