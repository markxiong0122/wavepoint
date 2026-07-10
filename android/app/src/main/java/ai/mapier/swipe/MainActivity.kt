package ai.mapier.swipe

import ai.mapier.swipe.audio.SpotifyPlaybackState
import ai.mapier.swipe.ui.PremiumBlockerKind
import ai.mapier.swipe.ui.WavepointActions
import ai.mapier.swipe.ui.WavepointApp
import ai.mapier.swipe.ui.WavepointUiState
import ai.mapier.swipe.ui.theme.WavepointTheme
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.lifecycle.lifecycleScope

class MainActivity : ComponentActivity() {
  private lateinit var runtime: WavepointRuntime

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge(
      statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
      navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
    )
    runtime = WavepointRuntime.create(this, lifecycleScope)
    setContent {
      val state by runtime.controller.state.collectAsState()
      WavepointTheme {
        WavepointApp(
          state = state,
          actions = actions(state),
        )
      }
    }
    if (!handleSpotifyCallback(intent)) runtime.controller.restore()
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleSpotifyCallback(intent)
  }

  override fun onStop() {
    runtime.controller.onStop()
    super.onStop()
  }

  private fun actions(state: WavepointUiState) = WavepointActions(
    onSignIn = runtime.controller::startSignIn,
    onRetry = {
      if (
        state is WavepointUiState.Blocked &&
        state.kind == PremiumBlockerKind.ELIGIBILITY_UNAVAILABLE
      ) {
        runtime.controller.retryEligibility()
      } else {
        runtime.controller.retry()
      }
    },
    onReconnect = runtime.controller::reconnect,
    onRemove = runtime.controller::removeCurrent,
    onKeep = runtime.controller::keepCurrent,
    onUndo = runtime.controller::undo,
    onReview = runtime.controller::beginReview,
    onCancelReview = runtime.controller::cancelReview,
    onConfirmRemoval = runtime.controller::confirmRemovals,
    onPreview = {
      if (
        state is WavepointUiState.Deck &&
        state.playbackState == SpotifyPlaybackState.APP_NOT_INSTALLED
      ) {
        openSpotifyAppListing()
      } else {
        runtime.controller.togglePreview()
      }
    },
    onOpenTrack = ::openUri,
    onStartAgain = runtime.controller::startAgain,
    onOpenSpotify = ::openSpotifyAppListing,
    onSignOut = runtime.controller::signOut,
    onDeleteAccount = runtime.controller::deleteAccount,
  )

  private fun handleSpotifyCallback(intent: Intent): Boolean {
    val uri = intent.data ?: return false
    if (uri.scheme != "ai.mapier.swipe" || uri.host != "login-callback") return false
    runtime.authenticator.handleDeepLink(
      intent = intent,
      onSession = runtime.controller::acceptAuthSession,
      onError = runtime.controller::rejectAuth,
    )
    return true
  }

  private fun openUri(uri: String) {
    runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uri))) }
  }

  private fun openSpotifyAppListing() {
    try {
      startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.spotify.music")))
    } catch (_: ActivityNotFoundException) {
      openUri("https://play.google.com/store/apps/details?id=com.spotify.music")
    }
  }
}
