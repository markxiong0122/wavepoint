package ai.mapier.swipe.ui

import ai.mapier.swipe.audio.SpotifyPlaybackState
import ai.mapier.swipe.cleanup.CleanupSummary
import ai.mapier.swipe.cleanup.LibraryTrack
import ai.mapier.swipe.ui.theme.CutRecordMark
import ai.mapier.swipe.ui.theme.WavepointPalette
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

enum class PremiumBlockerKind {
  PREMIUM_REQUIRED,
  RECONNECT_REQUIRED,
  ELIGIBILITY_UNAVAILABLE,
}

sealed interface WavepointUiState {
  data object Restoring : WavepointUiState
  data object Login : WavepointUiState
  data object Authorizing : WavepointUiState
  data object LoadingLibrary : WavepointUiState
  data object DeletingAccount : WavepointUiState
  data class Blocked(val kind: PremiumBlockerKind) : WavepointUiState
  data class Deck(
    val track: LibraryTrack,
    val completedCount: Int,
    val totalCount: Int,
    val reviewCount: Int,
    val playbackState: SpotifyPlaybackState,
    val playbackError: String? = null,
  ) : WavepointUiState
  data class Review(val tracks: List<LibraryTrack>) : WavepointUiState
  data class Committing(val count: Int) : WavepointUiState
  data class Complete(val summary: CleanupSummary) : WavepointUiState
  data class Error(
    val message: String,
    val canReturnToReview: Boolean,
  ) : WavepointUiState
}

data class WavepointActions(
  val onSignIn: () -> Unit = {},
  val onRetry: () -> Unit = {},
  val onReconnect: () -> Unit = {},
  val onRemove: () -> Unit = {},
  val onKeep: () -> Unit = {},
  val onUndo: () -> Unit = {},
  val onReview: () -> Unit = {},
  val onCancelReview: () -> Unit = {},
  val onConfirmRemoval: () -> Unit = {},
  val onPreview: () -> Unit = {},
  val onOpenTrack: (String) -> Unit = {},
  val onStartAgain: () -> Unit = {},
  val onOpenSpotify: () -> Unit = {},
  val onSignOut: () -> Unit = {},
  val onDeleteAccount: () -> Unit = {},
  val onAccount: () -> Unit = {},
)

@Composable
fun WavepointApp(
  state: WavepointUiState,
  actions: WavepointActions,
) {
  var showsAccount by remember { mutableStateOf(false) }
  Box(
    modifier = Modifier
      .fillMaxSize()
      .background(WavepointPalette.DarkSurface)
      .systemBarsPadding(),
  ) {
    when (state) {
      WavepointUiState.Restoring -> StatusScreen("TUNING THE DECK…")
      WavepointUiState.Authorizing -> StatusScreen("OPENING SPOTIFY…")
      WavepointUiState.LoadingLibrary -> StatusScreen("DIGGING UP BURIED SONGS…")
      WavepointUiState.DeletingAccount -> StatusScreen(
        "DELETING WAVEPOINT ACCOUNT…",
        accent = WavepointPalette.Remove,
      )
      WavepointUiState.Login -> LoginScreen(onSignIn = actions.onSignIn)
      is WavepointUiState.Blocked -> PremiumBlockerScreen(
        kind = state.kind,
        onRetry = actions.onRetry,
        onReconnect = actions.onReconnect,
      )
      is WavepointUiState.Deck -> CleanupDeckScreen(
        state,
        actions.copy(onAccount = { showsAccount = true }),
      )
      is WavepointUiState.Review -> RemovalReviewScreen(
        tracks = state.tracks,
        onBack = actions.onCancelReview,
        onConfirm = actions.onConfirmRemoval,
      )
      is WavepointUiState.Committing -> StatusScreen(
        "REMOVING ${state.count} FROM LIKED SONGS…",
        accent = WavepointPalette.Remove,
      )
      is WavepointUiState.Complete -> CleanupCompleteScreen(
        summary = state.summary,
        onStartAgain = actions.onStartAgain,
        onAccount = { showsAccount = true },
      )
      is WavepointUiState.Error -> ErrorScreen(state, actions)
    }
  }
  if (showsAccount) {
    AccountSheet(
      onDismiss = { showsAccount = false },
      onSignOut = {
        showsAccount = false
        actions.onSignOut()
      },
      onDeleteAccount = {
        showsAccount = false
        actions.onDeleteAccount()
      },
    )
  }
}

@Composable
private fun StatusScreen(
  title: String,
  accent: androidx.compose.ui.graphics.Color = WavepointPalette.Keep,
) {
  Column(
    modifier = Modifier.fillMaxSize(),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    CutRecordMark(Modifier.size(76.dp))
    Spacer(Modifier.height(18.dp))
    CircularProgressIndicator(color = accent)
    Spacer(Modifier.height(18.dp))
    Text(
      text = title,
      color = WavepointPalette.Paper,
      fontFamily = FontFamily.Monospace,
      fontWeight = FontWeight.Bold,
      fontSize = 12.sp,
      letterSpacing = 0.7.sp,
    )
  }
}

@Composable
private fun ErrorScreen(
  state: WavepointUiState.Error,
  actions: WavepointActions,
) {
  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(24.dp),
    verticalArrangement = Arrangement.Center,
  ) {
    CutRecordMark(Modifier.size(64.dp))
    Spacer(Modifier.height(18.dp))
    Text(
      "SPOTIFY HIT A SNAG",
      color = WavepointPalette.Remove,
      fontFamily = FontFamily.Monospace,
      fontWeight = FontWeight.Black,
      fontSize = 12.sp,
    )
    Spacer(Modifier.height(18.dp))
    Text(
      state.message,
      color = WavepointPalette.Paper,
      fontWeight = FontWeight.Bold,
      fontSize = 24.sp,
    )
    Spacer(Modifier.height(24.dp))
    WavepointActionButton(
      label = if (state.canReturnToReview) "BACK TO REVIEW" else "TRY AGAIN",
      color = WavepointPalette.Keep,
      onClick = actions.onRetry,
    )
  }
}
