package ai.mapier.swipe.ui

import ai.mapier.swipe.audio.PreviewCancellation
import ai.mapier.swipe.audio.PreviewScheduler
import ai.mapier.swipe.audio.SpotifyAppRemotePlayer
import ai.mapier.swipe.audio.SpotifyRemoteGateway
import ai.mapier.swipe.account.AccountDeleting
import ai.mapier.swipe.auth.AppSession
import ai.mapier.swipe.auth.SpotifyAuthSession
import ai.mapier.swipe.auth.SpotifyAuthenticator
import ai.mapier.swipe.auth.SpotifyProviderTokens
import ai.mapier.swipe.auth.SpotifyTokenStoring
import ai.mapier.swipe.cleanup.CleanupDeckBuilder
import ai.mapier.swipe.cleanup.CleanupSession
import ai.mapier.swipe.cleanup.LibraryTrack
import ai.mapier.swipe.spotify.SpotifyAccountEligibility
import ai.mapier.swipe.spotify.SpotifyAccountEligibilityChecker
import ai.mapier.swipe.spotify.SpotifyLibraryService
import ai.mapier.swipe.spotify.SpotifyWebApiErrorKind
import ai.mapier.swipe.spotify.SpotifyWebApiException
import java.time.Instant
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class WavepointControllerTest {
  @Test
  fun premiumRestoreLoadsTheDeckAndAutoplaysItsFirstCard() = runTest {
    val library = FakeLibraryService(listOf(track("buried")))
    val gateway = FakeRemoteGateway()
    val controller = controller(
      eligibility = SpotifyAccountEligibility.PREMIUM,
      library = library,
      gateway = gateway,
    )

    controller.restore()
    runCurrent()

    val state = controller.state.value as WavepointUiState.Deck
    assertEquals("buried", state.track.id)
    assertEquals(listOf("spotify:track:buried"), gateway.playCalls)
    assertEquals(1, library.savedTrackCalls)
  }

  @Test
  fun freeAccountIsBlockedBeforeTheLibraryLoads() = runTest {
    val library = FakeLibraryService(listOf(track("never-loaded")))
    val controller = controller(
      eligibility = SpotifyAccountEligibility.FREE,
      library = library,
    )

    controller.restore()
    runCurrent()

    assertEquals(
      WavepointUiState.Blocked(PremiumBlockerKind.PREMIUM_REQUIRED),
      controller.state.value,
    )
    assertEquals(0, library.savedTrackCalls)
  }

  @Test
  fun removeReviewAndConfirmCommitsOnlyAtTheExplicitBoundary() = runTest {
    val library = FakeLibraryService(listOf(track("remove-me")))
    val controller = controller(
      eligibility = SpotifyAccountEligibility.PREMIUM,
      library = library,
    )
    controller.restore()
    runCurrent()

    controller.removeCurrent()
    runCurrent()
    assertTrue(controller.state.value is WavepointUiState.Review)
    assertTrue(library.removalCalls.isEmpty())

    controller.confirmRemovals()
    runCurrent()

    assertEquals(listOf(listOf("spotify:track:remove-me")), library.removalCalls)
    assertEquals(
      WavepointUiState.Complete(
        ai.mapier.swipe.cleanup.CleanupSummary(decisionCount = 1, affectedCount = 1),
      ),
      controller.state.value,
    )
  }

  @Test
  fun failedRemovalRetainsTheReviewBatchForAVisibleRetry() = runTest {
    val library = FakeLibraryService(listOf(track("retry-me"))).apply {
      removalError = SpotifyWebApiException(
        kind = SpotifyWebApiErrorKind.PARTIAL_REMOVAL,
        committedCount = 0,
        remainingCount = 1,
      )
    }
    val controller = controller(
      eligibility = SpotifyAccountEligibility.PREMIUM,
      library = library,
    )
    controller.restore()
    runCurrent()
    controller.removeCurrent()
    runCurrent()

    controller.confirmRemovals()
    runCurrent()

    val error = controller.state.value as WavepointUiState.Error
    assertTrue(error.canReturnToReview)
    controller.retry()
    runCurrent()
    assertTrue(controller.state.value is WavepointUiState.Review)
  }

  @Test
  fun confirmedAccountDeletionReturnsToSignedOut() = runTest {
    val deletion = FakeAccountDeleting()
    val controller = controller(
      eligibility = SpotifyAccountEligibility.PREMIUM,
      library = FakeLibraryService(listOf(track("one"))),
      accountDeleting = deletion,
    )
    controller.restore()
    runCurrent()

    controller.deleteAccount()
    runCurrent()

    assertEquals(1, deletion.calls)
    assertEquals(WavepointUiState.Login, controller.state.value)
  }

  @Test
  fun failedAccountDeletionKeepsAVisibleNotDeletedError() = runTest {
    val deletion = FakeAccountDeleting(IllegalStateException("Account was not deleted."))
    val controller = controller(
      eligibility = SpotifyAccountEligibility.PREMIUM,
      library = FakeLibraryService(listOf(track("one"))),
      accountDeleting = deletion,
    )
    controller.restore()
    runCurrent()

    controller.deleteAccount()
    runCurrent()

    val error = controller.state.value as WavepointUiState.Error
    assertEquals("Account was not deleted.", error.message)
  }

  private fun kotlinx.coroutines.test.TestScope.controller(
    eligibility: SpotifyAccountEligibility,
    library: FakeLibraryService,
    gateway: FakeRemoteGateway = FakeRemoteGateway(),
    accountDeleting: AccountDeleting = FakeAccountDeleting(),
  ): WavepointController {
    val tokens = MemoryTokenStore(SpotifyProviderTokens("access", "refresh"))
    val appSession = AppSession(
      authenticator = RestoredAuthenticator(),
      tokenStore = tokens,
      eligibilityChecker = FixedEligibility(eligibility),
    )
    val player = SpotifyAppRemotePlayer(gateway, NoOpPreviewScheduler())
    return WavepointController(
      appSession = appSession,
      library = library,
      cleanupSession = CleanupSession(),
      deckBuilder = CleanupDeckBuilder(referenceDate = Instant.parse("2026-01-01T00:00:00Z")),
      player = player,
      accountDeleting = accountDeleting,
      scope = backgroundScope,
      deckSeed = { 42L },
    )
  }
}

private class FakeAccountDeleting(
  private val error: Throwable? = null,
) : AccountDeleting {
  var calls = 0

  override suspend fun deleteAccount() {
    calls += 1
    error?.let { throw it }
  }
}

private class FakeLibraryService(
  private val tracks: List<LibraryTrack>,
) : SpotifyLibraryService {
  var savedTrackCalls = 0
  var removalError: Throwable? = null
  val removalCalls = mutableListOf<List<String>>()

  override suspend fun fetchSavedTracks(): List<LibraryTrack> {
    savedTrackCalls += 1
    return tracks
  }

  override suspend fun fetchRecentlyPlayedTrackIds(): Set<String> = emptySet()

  override suspend fun removeFromLibrary(uris: List<String>): Int {
    removalCalls += uris
    removalError?.let { throw it }
    return uris.size
  }
}

private class RestoredAuthenticator : SpotifyAuthenticator {
  override suspend fun restoreSession() = SpotifyAuthSession("supabase", providerTokens = null)
  override suspend fun startSignIn() = Unit
  override suspend fun signOut() = Unit
  override suspend fun clearLocalSession() = Unit
}

private class MemoryTokenStore(
  private var tokens: SpotifyProviderTokens?,
) : SpotifyTokenStoring {
  override fun save(tokens: SpotifyProviderTokens) {
    this.tokens = tokens
  }

  override fun load(): SpotifyProviderTokens? = tokens

  override fun clear() {
    tokens = null
  }
}

private class FixedEligibility(
  private val eligibility: SpotifyAccountEligibility,
) : SpotifyAccountEligibilityChecker {
  override suspend fun fetchAccountEligibility() = eligibility
}

private class FakeRemoteGateway : SpotifyRemoteGateway {
  override var isConnected = false
    private set
  val playCalls = mutableListOf<String>()

  override suspend fun connect(showAuthView: Boolean) {
    isConnected = true
  }

  override suspend fun play(uri: String) {
    playCalls += uri
  }

  override suspend fun seekTo(positionMilliseconds: Long) = Unit
  override suspend fun pause() = Unit
  override fun disconnect() {
    isConnected = false
  }
}

private class NoOpPreviewScheduler : PreviewScheduler {
  override fun schedule(
    delayMilliseconds: Long,
    action: suspend () -> Unit,
  ) = PreviewCancellation {}
}

private fun track(id: String) = LibraryTrack(
  id = id,
  playbackId = "spotify:track:$id",
  commitId = "spotify:track:$id",
  title = "Song $id",
  artistNames = listOf("Artist"),
  artworkUrl = null,
  destinationUrl = "https://open.spotify.com/track/$id",
  durationMilliseconds = 180_000,
  addedAt = Instant.parse("2018-01-01T00:00:00Z"),
)
