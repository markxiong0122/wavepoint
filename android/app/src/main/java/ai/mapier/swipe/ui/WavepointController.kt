package ai.mapier.swipe.ui

import ai.mapier.swipe.account.AccountDeleting
import ai.mapier.swipe.analytics.AnalyticsCapturing
import ai.mapier.swipe.analytics.AnalyticsErrorCategory
import ai.mapier.swipe.analytics.AnalyticsEvent
import ai.mapier.swipe.analytics.AnalyticsProvider
import ai.mapier.swipe.analytics.CrashReporting
import ai.mapier.swipe.analytics.NoOpAnalytics
import ai.mapier.swipe.analytics.NoOpCrashReporting
import ai.mapier.swipe.audio.SpotifyAppRemotePlayer
import ai.mapier.swipe.audio.SpotifyPlaybackState
import ai.mapier.swipe.auth.AppSession
import ai.mapier.swipe.auth.AppSessionState
import ai.mapier.swipe.auth.SpotifyAuthSession
import ai.mapier.swipe.cleanup.CleanupDeckBuilder
import ai.mapier.swipe.cleanup.CleanupSession
import ai.mapier.swipe.cleanup.CleanupSessionState
import ai.mapier.swipe.spotify.SpotifyLibraryService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class WavepointController(
  private val appSession: AppSession,
  private val library: SpotifyLibraryService,
  private val cleanupSession: CleanupSession,
  private val deckBuilder: CleanupDeckBuilder,
  private val player: SpotifyAppRemotePlayer,
  private val accountDeleting: AccountDeleting,
  private val scope: CoroutineScope,
  private val analytics: AnalyticsCapturing = NoOpAnalytics,
  private val crashReporting: CrashReporting = NoOpCrashReporting,
  private val deckSeed: () -> Long = { kotlin.random.Random.nextLong() },
) {
  private val mutableState = MutableStateFlow<WavepointUiState>(WavepointUiState.Restoring)
  val state: StateFlow<WavepointUiState> = mutableState.asStateFlow()

  init {
    scope.launch {
      player.status.collect {
        if (
          cleanupSession.state == CleanupSessionState.DECIDING &&
          mutableState.value is WavepointUiState.Deck
        ) {
          publishDeck()
        }
      }
    }
  }

  fun restore() {
    scope.launch {
      mutableState.value = WavepointUiState.Restoring
      appSession.restore()
      routeSession()
    }
  }

  fun startSignIn() {
    scope.launch {
      analytics.capture(AnalyticsEvent.ProviderConnectionStarted(AnalyticsProvider.SPOTIFY))
      appSession.startSignIn()
      routeSession()
    }
  }

  fun acceptAuthSession(session: SpotifyAuthSession) {
    scope.launch {
      appSession.accept(session)
      routeSession()
    }
  }

  fun rejectAuth(error: Throwable) {
    scope.launch {
      analytics.capture(
        AnalyticsEvent.ProviderConnectionFailed(
          AnalyticsProvider.SPOTIFY,
          AnalyticsErrorCategory.AUTHORIZATION,
        ),
      )
      crashReporting.record(AnalyticsErrorCategory.AUTHORIZATION)
      appSession.reject(error)
      routeSessionWithoutLoading()
    }
  }

  fun retryEligibility() {
    scope.launch {
      appSession.retryEligibility()
      routeSession()
    }
  }

  fun reconnect() {
    scope.launch {
      appSession.signOut()
      if (appSession.state == AppSessionState.SIGNED_OUT) {
        appSession.startSignIn()
      }
      routeSession()
    }
  }

  fun signOut() {
    scope.launch {
      mutableState.value = WavepointUiState.Restoring
      player.onLifecycleStop()
      appSession.signOut()
      routeSession()
    }
  }

  fun deleteAccount() {
    scope.launch {
      mutableState.value = WavepointUiState.DeletingAccount
      player.onLifecycleStop()
      try {
        accountDeleting.deleteAccount()
        appSession.clearAfterAccountDeletion()
        analytics.capture(AnalyticsEvent.AccountDeleted)
        routeSession()
      } catch (error: Throwable) {
        crashReporting.record(AnalyticsErrorCategory.UNKNOWN)
        mutableState.value = WavepointUiState.Error(
          message = error.message ?: "Your Wavepoint account was not deleted.",
          canReturnToReview = false,
        )
      }
    }
  }

  fun removeCurrent() {
    scope.launch {
      val firstDecision = cleanupSession.completedCount == 0
      cleanupSession.tossCurrent()
      captureDecisionTransition(firstDecision)
      presentCleanup()
    }
  }

  fun keepCurrent() {
    scope.launch {
      val firstDecision = cleanupSession.completedCount == 0
      cleanupSession.keepCurrent()
      captureDecisionTransition(firstDecision)
      presentCleanup()
    }
  }

  fun undo() {
    scope.launch {
      cleanupSession.undo()
      presentCleanup()
    }
  }

  fun beginReview() {
    scope.launch {
      cleanupSession.beginReview()
      if (cleanupSession.state == CleanupSessionState.REVIEWING) {
        analytics.capture(AnalyticsEvent.ReviewOpened(AnalyticsProvider.SPOTIFY))
      }
      presentCleanup()
    }
  }

  fun cancelReview() {
    scope.launch {
      cleanupSession.cancelReview()
      presentCleanup()
    }
  }

  fun confirmRemovals() {
    scope.launch {
      val uris = cleanupSession.beginCommit()
      mutableState.value = WavepointUiState.Committing(uris.size)
      player.stopPreview()
      try {
        val removed = library.removeFromLibrary(uris)
        cleanupSession.finishCommit(removed)
        analytics.capture(AnalyticsEvent.CleanupSessionCompleted(AnalyticsProvider.SPOTIFY))
        presentCleanup()
      } catch (error: Throwable) {
        crashReporting.record(AnalyticsErrorCategory.COMMIT)
        cleanupSession.failCommit()
        mutableState.value = WavepointUiState.Error(
          message = error.message ?: "Spotify could not complete the removal.",
          canReturnToReview = true,
        )
      }
    }
  }

  fun retry() {
    scope.launch {
      when {
        cleanupSession.state == CleanupSessionState.REVIEWING ->
          presentCleanup(autoplay = false)
        appSession.state == AppSessionState.SIGNED_IN -> loadLibrary()
        else -> {
          appSession.startSignIn()
          routeSession()
        }
      }
    }
  }

  fun startAgain() {
    scope.launch { loadLibrary() }
  }

  fun togglePreview() {
    val track = cleanupSession.currentTrack ?: return
    scope.launch {
      when (player.state) {
        SpotifyPlaybackState.PLAYING -> player.stopPreview()
        SpotifyPlaybackState.AUTHORIZATION_REQUIRED ->
          player.authorizeAndPlay(track.playbackId)
        SpotifyPlaybackState.APP_NOT_INSTALLED -> Unit
        else -> player.playPreview(track.playbackId)
      }
      publishDeck()
    }
  }

  fun onStop() {
    player.onLifecycleStop()
  }

  private suspend fun routeSession() {
    when (appSession.state) {
      AppSessionState.SIGNED_IN -> {
        analytics.capture(AnalyticsEvent.ProviderConnectionSucceeded(AnalyticsProvider.SPOTIFY))
        loadLibrary()
      }
      else -> routeSessionWithoutLoading()
    }
  }

  private fun routeSessionWithoutLoading() {
    mutableState.value = when (appSession.state) {
      AppSessionState.RESTORING -> WavepointUiState.Restoring
      AppSessionState.SIGNED_OUT -> WavepointUiState.Login
      AppSessionState.AUTHORIZING -> WavepointUiState.Authorizing
      AppSessionState.SIGNED_IN -> WavepointUiState.LoadingLibrary
      AppSessionState.SPOTIFY_PREMIUM_REQUIRED ->
        WavepointUiState.Blocked(PremiumBlockerKind.PREMIUM_REQUIRED)
      AppSessionState.SPOTIFY_RECONNECT_REQUIRED ->
        WavepointUiState.Blocked(PremiumBlockerKind.RECONNECT_REQUIRED)
      AppSessionState.SPOTIFY_ELIGIBILITY_UNAVAILABLE ->
        WavepointUiState.Blocked(PremiumBlockerKind.ELIGIBILITY_UNAVAILABLE)
      AppSessionState.FAILED -> WavepointUiState.Error(
        message = appSession.errorMessage ?: "Spotify sign-in failed.",
        canReturnToReview = false,
      )
    }
  }

  private suspend fun loadLibrary() {
    mutableState.value = WavepointUiState.LoadingLibrary
    try {
      val tracks = library.fetchSavedTracks()
      cleanupSession.load(deckBuilder.build(tracks, seed = deckSeed()))
      analytics.capture(AnalyticsEvent.CleanupDeckLoaded(AnalyticsProvider.SPOTIFY))
      presentCleanup()
    } catch (error: Throwable) {
      crashReporting.record(AnalyticsErrorCategory.LIBRARY_LOAD)
      mutableState.value = WavepointUiState.Error(
        message = error.message ?: "Spotify could not load your Liked Songs.",
        canReturnToReview = false,
      )
    }
  }

  private suspend fun presentCleanup(autoplay: Boolean = true) {
    when (cleanupSession.state) {
      CleanupSessionState.IDLE -> mutableState.value = WavepointUiState.LoadingLibrary
      CleanupSessionState.DECIDING -> {
        publishDeck()
        if (autoplay) {
          cleanupSession.currentTrack?.let { player.playPreview(it.playbackId) }
          publishDeck()
        }
      }
      CleanupSessionState.REVIEWING -> {
        player.stopPreview()
        mutableState.value = WavepointUiState.Review(cleanupSession.stagedRemovals)
      }
      CleanupSessionState.COMMITTING -> {
        mutableState.value = WavepointUiState.Committing(cleanupSession.stagedRemovals.size)
      }
      CleanupSessionState.COMPLETE -> {
        player.stopPreview()
        mutableState.value = WavepointUiState.Complete(checkNotNull(cleanupSession.summary))
      }
    }
  }

  private fun publishDeck() {
    val track = cleanupSession.currentTrack ?: return
    mutableState.value = WavepointUiState.Deck(
      track = track,
      completedCount = cleanupSession.completedCount,
      totalCount = cleanupSession.totalCount,
      reviewCount = cleanupSession.stagedRemovals.size,
      playbackState = player.state,
      playbackError = player.errorMessage,
    )
  }

  private fun captureDecisionTransition(firstDecision: Boolean) {
    if (firstDecision) {
      analytics.capture(AnalyticsEvent.FirstDecisionCompleted(AnalyticsProvider.SPOTIFY))
    }
    when (cleanupSession.state) {
      CleanupSessionState.REVIEWING ->
        analytics.capture(AnalyticsEvent.ReviewOpened(AnalyticsProvider.SPOTIFY))
      CleanupSessionState.COMPLETE ->
        analytics.capture(AnalyticsEvent.CleanupSessionCompleted(AnalyticsProvider.SPOTIFY))
      else -> Unit
    }
  }
}
