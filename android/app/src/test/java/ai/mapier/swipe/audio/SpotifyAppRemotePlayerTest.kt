package ai.mapier.swipe.audio

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SpotifyAppRemotePlayerTest {
  @Test
  fun connectsWithoutAnotherAuthViewThenPlaysSeeksAndPausesAfterFifteenSeconds() = runTest {
    val gateway = FakeSpotifyRemoteGateway()
    val scheduler = FakePreviewScheduler()
    val player = SpotifyAppRemotePlayer(gateway, scheduler)

    player.playPreview("spotify:track:one")

    assertEquals(listOf(false), gateway.connectCalls)
    assertEquals(listOf("spotify:track:one"), gateway.playCalls)
    assertEquals(listOf(0L), gateway.seekCalls)
    assertEquals(SpotifyPlaybackState.PLAYING, player.state)
    assertEquals(15_000L, scheduler.tasks.single().delayMilliseconds)

    scheduler.tasks.single().runEvenIfCancelled()

    assertEquals(1, gateway.pauseCalls)
    assertEquals(SpotifyPlaybackState.READY, player.state)
  }

  @Test
  fun missingSpotifyAppHasADedicatedState() = runTest {
    val gateway = FakeSpotifyRemoteGateway().apply {
      connectError = SpotifyRemoteException(SpotifyRemoteFailure.APP_NOT_INSTALLED)
    }
    val player = SpotifyAppRemotePlayer(gateway, FakePreviewScheduler())

    player.playPreview("spotify:track:one")

    assertEquals(SpotifyPlaybackState.APP_NOT_INSTALLED, player.state)
  }

  @Test
  fun authorizationFailureCanRetryWithTheSdkAuthView() = runTest {
    val gateway = FakeSpotifyRemoteGateway().apply {
      connectError = SpotifyRemoteException(SpotifyRemoteFailure.AUTHORIZATION_REQUIRED)
    }
    val player = SpotifyAppRemotePlayer(gateway, FakePreviewScheduler())

    player.playPreview("spotify:track:one")
    assertEquals(SpotifyPlaybackState.AUTHORIZATION_REQUIRED, player.state)

    gateway.connectError = null
    player.authorizeAndPlay("spotify:track:one")

    assertEquals(listOf(false, true), gateway.connectCalls)
    assertEquals(SpotifyPlaybackState.PLAYING, player.state)
  }

  @Test
  fun changingCardsCancelsTheOldTimerAndSuppressesItsStaleCallback() = runTest {
    val gateway = FakeSpotifyRemoteGateway()
    val scheduler = FakePreviewScheduler()
    val player = SpotifyAppRemotePlayer(gateway, scheduler)

    player.playPreview("spotify:track:one")
    player.playPreview("spotify:track:two")

    assertTrue(scheduler.tasks.first().isCancelled)
    scheduler.tasks.first().runEvenIfCancelled()
    assertEquals(0, gateway.pauseCalls)

    scheduler.tasks.last().runEvenIfCancelled()
    assertEquals(1, gateway.pauseCalls)
    assertEquals(listOf("spotify:track:one", "spotify:track:two"), gateway.playCalls)
  }

  @Test
  fun lifecycleStopCancelsPlaybackWorkAndDisconnects() = runTest {
    val gateway = FakeSpotifyRemoteGateway()
    val scheduler = FakePreviewScheduler()
    val player = SpotifyAppRemotePlayer(gateway, scheduler)

    player.playPreview("spotify:track:one")
    player.onLifecycleStop()
    scheduler.tasks.single().runEvenIfCancelled()

    assertTrue(scheduler.tasks.single().isCancelled)
    assertEquals(1, gateway.disconnectCalls)
    assertEquals(0, gateway.pauseCalls)
    assertEquals(SpotifyPlaybackState.IDLE, player.state)
  }
}

private class FakeSpotifyRemoteGateway : SpotifyRemoteGateway {
  override var isConnected: Boolean = false
    private set

  var connectError: Throwable? = null
  val connectCalls = mutableListOf<Boolean>()
  val playCalls = mutableListOf<String>()
  val seekCalls = mutableListOf<Long>()
  var pauseCalls = 0
  var disconnectCalls = 0

  override suspend fun connect(showAuthView: Boolean) {
    connectCalls += showAuthView
    connectError?.let { throw it }
    isConnected = true
  }

  override suspend fun play(uri: String) {
    playCalls += uri
  }

  override suspend fun seekTo(positionMilliseconds: Long) {
    seekCalls += positionMilliseconds
  }

  override suspend fun pause() {
    pauseCalls += 1
  }

  override fun disconnect() {
    disconnectCalls += 1
    isConnected = false
  }
}

private class FakePreviewScheduler : PreviewScheduler {
  val tasks = mutableListOf<Task>()

  override fun schedule(
    delayMilliseconds: Long,
    action: suspend () -> Unit,
  ): PreviewCancellation = Task(delayMilliseconds, action).also(tasks::add)

  class Task(
    val delayMilliseconds: Long,
    private val action: suspend () -> Unit,
  ) : PreviewCancellation {
    var isCancelled = false
      private set

    override fun cancel() {
      isCancelled = true
    }

    suspend fun runEvenIfCancelled() {
      action()
    }
  }
}
