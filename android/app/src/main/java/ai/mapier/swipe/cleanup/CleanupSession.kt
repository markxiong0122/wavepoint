package ai.mapier.swipe.cleanup

enum class CleanupSessionState {
  IDLE,
  DECIDING,
  REVIEWING,
  COMMITTING,
  COMPLETE,
}

enum class CleanupOutcome {
  KEEP,
  TOSS,
}

data class CleanupDecision(
  val track: LibraryTrack,
  val outcome: CleanupOutcome,
)

data class CleanupSummary(
  val decisionCount: Int,
  val affectedCount: Int,
)

class CleanupSession {
  var state: CleanupSessionState = CleanupSessionState.IDLE
    private set

  var summary: CleanupSummary? = null
    private set

  private var deck: List<LibraryTrack> = emptyList()
  private val decisions = mutableListOf<CleanupDecision>()

  val currentTrack: LibraryTrack?
    get() = deck.getOrNull(decisions.size)

  val stagedRemovals: List<LibraryTrack>
    get() = decisions
      .filter { it.outcome == CleanupOutcome.TOSS }
      .map { it.track }

  val completedCount: Int
    get() = decisions.size

  val totalCount: Int
    get() = deck.size

  fun load(tracks: List<LibraryTrack>) {
    deck = tracks
    decisions.clear()
    summary = null
    if (deck.isEmpty()) {
      summary = CleanupSummary(decisionCount = 0, affectedCount = 0)
      state = CleanupSessionState.COMPLETE
    } else {
      state = CleanupSessionState.DECIDING
    }
  }

  fun keepCurrent() {
    decide(CleanupOutcome.KEEP)
  }

  fun tossCurrent() {
    decide(CleanupOutcome.TOSS)
  }

  fun undo() {
    if (state != CleanupSessionState.DECIDING || decisions.isEmpty()) return
    decisions.removeLast()
  }

  fun beginReview() {
    if (state != CleanupSessionState.DECIDING) return
    finishDeciding()
  }

  fun cancelReview() {
    if (state == CleanupSessionState.REVIEWING) {
      state = CleanupSessionState.DECIDING
    }
  }

  fun beginCommit(): List<String> {
    check(state == CleanupSessionState.REVIEWING)
    state = CleanupSessionState.COMMITTING
    return stagedRemovals.map { it.commitId }
  }

  fun finishCommit(affectedCount: Int) {
    check(state == CleanupSessionState.COMMITTING)
    summary = CleanupSummary(
      decisionCount = decisions.size,
      affectedCount = affectedCount,
    )
    state = CleanupSessionState.COMPLETE
  }

  private fun decide(outcome: CleanupOutcome) {
    if (state != CleanupSessionState.DECIDING) return
    val track = currentTrack ?: return
    decisions += CleanupDecision(track, outcome)
    if (decisions.size == deck.size) {
      finishDeciding()
    }
  }

  private fun finishDeciding() {
    if (stagedRemovals.isEmpty()) {
      summary = CleanupSummary(
        decisionCount = decisions.size,
        affectedCount = 0,
      )
      state = CleanupSessionState.COMPLETE
    } else {
      state = CleanupSessionState.REVIEWING
    }
  }
}
