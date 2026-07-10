package ai.mapier.swipe.ui

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
  private val scope: CoroutineScope,
  private val deckSeed: () -> Long = { kotlin.random.Random.nextLong() },
) {
  private val mutableState = MutableStateFlow<WavepointUiState>(WavepointUiState.Restoring)
  val state: StateFlow<WavepointUiState> = mutableState.asStateFlow()

  init {
    scope.launch {
      player.status.collect {
        if (cleanupSession.state == CleanupSessionState.DECIDING) publishDeck()
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

  fun removeCurrent() {
    scope.launch {
      cleanupSession.tossCurrent()
      presentCleanup()
    }
  }

  fun keepCurrent() {
    scope.launch {
      cleanupSession.keepCurrent()
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
        presentCleanup()
      } catch (error: Throwable) {
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
      if (cleanupSession.state == CleanupSessionState.REVIEWING) {
        presentCleanup(autoplay = false)
      } else {
        loadLibrary()
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
      AppSessionState.SIGNED_IN -> loadLibrary()
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
      val recent = library.fetchRecentlyPlayedTrackIds()
      cleanupSession.load(deckBuilder.build(tracks, recent, seed = deckSeed()))
      presentCleanup()
    } catch (error: Throwable) {
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
}
