package ai.mapier.swipe.audio

import android.content.Context
import com.spotify.android.appremote.api.ConnectionParams
import com.spotify.android.appremote.api.Connector
import com.spotify.android.appremote.api.SpotifyAppRemote
import com.spotify.android.appremote.api.error.AuthenticationFailedException
import com.spotify.android.appremote.api.error.CouldNotFindSpotifyApp
import com.spotify.android.appremote.api.error.NotLoggedInException
import com.spotify.android.appremote.api.error.UserNotAuthorizedException
import com.spotify.protocol.client.CallResult
import com.spotify.protocol.types.Empty
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class SpotifyRemoteFailure {
  APP_NOT_INSTALLED,
  AUTHORIZATION_REQUIRED,
  UNKNOWN,
}

class SpotifyRemoteException(
  val failure: SpotifyRemoteFailure,
  cause: Throwable? = null,
) : Exception(message(failure), cause) {
  private companion object {
    fun message(failure: SpotifyRemoteFailure): String = when (failure) {
      SpotifyRemoteFailure.APP_NOT_INSTALLED ->
        "Install Spotify to hear song previews."
      SpotifyRemoteFailure.AUTHORIZATION_REQUIRED ->
        "Spotify needs permission to play previews."
      SpotifyRemoteFailure.UNKNOWN ->
        "Spotify playback could not connect."
    }
  }
}

enum class SpotifyPlaybackState {
  IDLE,
  CONNECTING,
  READY,
  PLAYING,
  APP_NOT_INSTALLED,
  AUTHORIZATION_REQUIRED,
  FAILED,
}

data class SpotifyPlaybackStatus(
  val state: SpotifyPlaybackState,
  val errorMessage: String? = null,
)

interface SpotifyRemoteGateway {
  val isConnected: Boolean

  suspend fun connect(showAuthView: Boolean)
  suspend fun play(uri: String)
  suspend fun seekTo(positionMilliseconds: Long)
  suspend fun pause()
  fun disconnect()
}

fun interface PreviewCancellation {
  fun cancel()
}

interface PreviewScheduler {
  fun schedule(
    delayMilliseconds: Long,
    action: suspend () -> Unit,
  ): PreviewCancellation
}

class CoroutinePreviewScheduler(
  private val scope: CoroutineScope,
) : PreviewScheduler {
  override fun schedule(
    delayMilliseconds: Long,
    action: suspend () -> Unit,
  ): PreviewCancellation {
    val job = scope.launch {
      delay(delayMilliseconds)
      action()
    }
    return PreviewCancellation(job::cancel)
  }
}

class SpotifyAppRemotePlayer(
  private val gateway: SpotifyRemoteGateway,
  private val scheduler: PreviewScheduler,
) {
  private val mutableStatus = MutableStateFlow(
    SpotifyPlaybackStatus(SpotifyPlaybackState.IDLE),
  )
  val status: StateFlow<SpotifyPlaybackStatus> = mutableStatus.asStateFlow()

  var state: SpotifyPlaybackState
    get() = mutableStatus.value.state
    private set(value) {
      mutableStatus.value = mutableStatus.value.copy(state = value)
    }

  var errorMessage: String?
    get() = mutableStatus.value.errorMessage
    private set(value) {
      mutableStatus.value = mutableStatus.value.copy(errorMessage = value)
    }

  private var timer: PreviewCancellation? = null
  private var requestGeneration = 0L

  suspend fun playPreview(uri: String) {
    play(uri, showAuthView = false)
  }

  suspend fun authorizeAndPlay(uri: String) {
    play(uri, showAuthView = true)
  }

  suspend fun stopPreview() {
    invalidatePendingPlayback()
    if (!gateway.isConnected) {
      state = SpotifyPlaybackState.IDLE
      return
    }
    runCatching { gateway.pause() }
      .onSuccess { state = SpotifyPlaybackState.READY }
      .onFailure(::recordFailure)
  }

  fun onLifecycleStop() {
    invalidatePendingPlayback()
    gateway.disconnect()
    errorMessage = null
    state = SpotifyPlaybackState.IDLE
  }

  private suspend fun play(
    uri: String,
    showAuthView: Boolean,
  ) {
    invalidatePendingPlayback()
    val generation = requestGeneration
    errorMessage = null

    if (!gateway.isConnected) {
      state = SpotifyPlaybackState.CONNECTING
      try {
        gateway.connect(showAuthView)
      } catch (error: Throwable) {
        recordFailure(error)
        return
      }
    }

    try {
      gateway.play(uri)
      if (generation != requestGeneration) return
      gateway.seekTo(0)
      if (generation != requestGeneration) return
      state = SpotifyPlaybackState.PLAYING
      timer = scheduler.schedule(PREVIEW_MILLISECONDS) {
        if (generation != requestGeneration || !gateway.isConnected) return@schedule
        runCatching { gateway.pause() }
          .onSuccess {
            if (generation == requestGeneration) state = SpotifyPlaybackState.READY
          }
          .onFailure {
            if (generation == requestGeneration) recordFailure(it)
          }
      }
    } catch (error: Throwable) {
      recordFailure(error)
    }
  }

  private fun invalidatePendingPlayback() {
    requestGeneration += 1
    timer?.cancel()
    timer = null
  }

  private fun recordFailure(error: Throwable) {
    errorMessage = error.message
    state = when ((error as? SpotifyRemoteException)?.failure) {
      SpotifyRemoteFailure.APP_NOT_INSTALLED -> SpotifyPlaybackState.APP_NOT_INSTALLED
      SpotifyRemoteFailure.AUTHORIZATION_REQUIRED ->
        SpotifyPlaybackState.AUTHORIZATION_REQUIRED
      SpotifyRemoteFailure.UNKNOWN, null -> SpotifyPlaybackState.FAILED
    }
  }

  private companion object {
    const val PREVIEW_MILLISECONDS = 15_000L
  }
}

class SpotifySdkRemoteGateway(
  context: Context,
  private val clientId: String,
  private val redirectUri: String,
) : SpotifyRemoteGateway {
  private val applicationContext = context.applicationContext
  private var remote: SpotifyAppRemote? = null

  override val isConnected: Boolean
    get() = remote?.isConnected == true

  override suspend fun connect(showAuthView: Boolean) {
    if (isConnected) return
    remote = suspendCancellableCoroutine { continuation ->
      val params = ConnectionParams.Builder(clientId)
        .setRedirectUri(redirectUri)
        .showAuthView(showAuthView)
        .build()
      SpotifyAppRemote.connect(
        applicationContext,
        params,
        object : Connector.ConnectionListener {
          override fun onConnected(spotifyAppRemote: SpotifyAppRemote) {
            if (continuation.isActive) continuation.resume(spotifyAppRemote)
          }

          override fun onFailure(error: Throwable) {
            if (continuation.isActive) continuation.resumeWithException(error.toRemoteException())
          }
        },
      )
    }
  }

  override suspend fun play(uri: String) {
    requireRemote().playerApi.play(uri).awaitCompletion()
  }

  override suspend fun seekTo(positionMilliseconds: Long) {
    requireRemote().playerApi.seekTo(positionMilliseconds).awaitCompletion()
  }

  override suspend fun pause() {
    requireRemote().playerApi.pause().awaitCompletion()
  }

  override fun disconnect() {
    SpotifyAppRemote.disconnect(remote)
    remote = null
  }

  private fun requireRemote(): SpotifyAppRemote = remote?.takeIf(SpotifyAppRemote::isConnected)
    ?: throw SpotifyRemoteException(SpotifyRemoteFailure.UNKNOWN)

  private suspend fun CallResult<Empty>.awaitCompletion() {
    suspendCancellableCoroutine { continuation ->
      setResultCallback {
        if (continuation.isActive) continuation.resume(Unit)
      }
      setErrorCallback { error ->
        if (continuation.isActive) continuation.resumeWithException(error.toRemoteException())
      }
      continuation.invokeOnCancellation { cancel() }
    }
  }

  private fun Throwable.toRemoteException(): SpotifyRemoteException = SpotifyRemoteException(
    failure = when (this) {
      is CouldNotFindSpotifyApp -> SpotifyRemoteFailure.APP_NOT_INSTALLED
      is UserNotAuthorizedException,
      is AuthenticationFailedException,
      is NotLoggedInException,
      -> SpotifyRemoteFailure.AUTHORIZATION_REQUIRED
      else -> SpotifyRemoteFailure.UNKNOWN
    },
    cause = this,
  )
}
