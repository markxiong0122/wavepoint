package ai.mapier.swipe.cleanup

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CleanupSessionTest {
  @Test
  fun keepTossAndUndoRestoreThePreviousCard() {
    val session = CleanupSession()
    val first = track("first")
    val second = track("second")
    session.load(listOf(first, second))

    session.keepCurrent()
    assertEquals(second, session.currentTrack)
    session.tossCurrent()
    assertEquals(CleanupSessionState.REVIEWING, session.state)
    assertEquals(listOf(second), session.stagedRemovals)

    session.cancelReview()
    session.undo()

    assertEquals(CleanupSessionState.DECIDING, session.state)
    assertEquals(second, session.currentTrack)
    assertTrue(session.stagedRemovals.isEmpty())
  }

  @Test
  fun reviewBoundaryReturnsOnlyStagedCommitIds() {
    val session = CleanupSession()
    val first = track("first")
    session.load(listOf(first, track("unseen")))
    session.tossCurrent()
    session.beginReview()

    val ids = session.beginCommit()

    assertEquals(listOf(first.commitId), ids)
    assertEquals(CleanupSessionState.COMMITTING, session.state)
    session.finishCommit(affectedCount = 1)
    assertEquals(CleanupSessionState.COMPLETE, session.state)
    assertEquals(CleanupSummary(decisionCount = 1, affectedCount = 1), session.summary)
  }

  @Test
  fun keepingEverySongCompletesWithoutACommit() {
    val session = CleanupSession()
    session.load(listOf(track("one")))

    session.keepCurrent()

    assertEquals(CleanupSessionState.COMPLETE, session.state)
    assertNull(session.currentTrack)
    assertEquals(CleanupSummary(decisionCount = 1, affectedCount = 0), session.summary)
  }

  @Test
  fun failedCommitReturnsToTheSameReviewBoundary() {
    val session = CleanupSession()
    session.load(listOf(track("one")))
    session.tossCurrent()
    session.beginCommit()

    session.failCommit()

    assertEquals(CleanupSessionState.REVIEWING, session.state)
    assertEquals(listOf("one"), session.stagedRemovals.map { it.id })
  }

  private fun track(id: String) = LibraryTrack(
    id = id,
    playbackId = "spotify:track:$id",
    commitId = "spotify:track:$id",
    title = "Track $id",
    artistNames = listOf("Artist"),
    artworkUrl = null,
    destinationUrl = "https://open.spotify.com/track/$id",
    durationMilliseconds = 180_000,
    addedAt = Instant.EPOCH,
  )
}
