package ai.mapier.swipe.ui

import ai.mapier.swipe.ui.theme.CutRecordMark
import ai.mapier.swipe.ui.theme.WavepointPalette
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun PremiumBlockerScreen(
  kind: PremiumBlockerKind,
  onRetry: () -> Unit,
  onReconnect: () -> Unit,
) {
  val copy = when (kind) {
    PremiumBlockerKind.PREMIUM_REQUIRED -> BlockerCopy(
      eyebrow = "PREMIUM KEEPS THE BEAT",
      title = "SPOTIFY PREMIUM REQUIRED",
      detail = "Wavepoint uses Spotify App Remote to autoplay each card. Spotify only enables that playback for Premium accounts.",
      primary = "USE ANOTHER SPOTIFY ACCOUNT",
      retryFirst = false,
    )
    PremiumBlockerKind.RECONNECT_REQUIRED -> BlockerCopy(
      eyebrow = "SPOTIFY COULDN'T VERIFY YOU",
      title = "RECONNECT SPOTIFY",
      detail = "This account may not be on the app's Spotify tester allowlist yet, or its authorization expired.",
      primary = "RECONNECT SPOTIFY",
      retryFirst = false,
    )
    PremiumBlockerKind.ELIGIBILITY_UNAVAILABLE -> BlockerCopy(
      eyebrow = "SPOTIFY MISSED A BEAT",
      title = "WE COULDN'T CHECK PREMIUM",
      detail = "Your credentials are still safe on this device. Retry the check before reconnecting.",
      primary = "TRY AGAIN",
      retryFirst = true,
    )
  }

  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(24.dp),
  ) {
    Spacer(Modifier.weight(1f))
    CutRecordMark(Modifier.size(72.dp))
    Spacer(Modifier.height(24.dp))
    Text(
      copy.eyebrow,
      color = WavepointPalette.Remove,
      fontFamily = FontFamily.Monospace,
      fontWeight = FontWeight.Black,
      fontSize = 11.sp,
    )
    Spacer(Modifier.height(14.dp))
    Text(
      copy.title,
      color = WavepointPalette.Paper,
      fontWeight = FontWeight.Black,
      fontSize = 34.sp,
      lineHeight = 36.sp,
    )
    Spacer(Modifier.height(16.dp))
    Text(
      copy.detail,
      color = WavepointPalette.Paper.copy(alpha = 0.7f),
      fontWeight = FontWeight.Medium,
      fontSize = 16.sp,
      lineHeight = 22.sp,
    )
    Spacer(Modifier.height(28.dp))
    WavepointActionButton(
      label = copy.primary,
      color = WavepointPalette.Keep,
      onClick = if (copy.retryFirst) onRetry else onReconnect,
    )
    if (copy.retryFirst) {
      Spacer(Modifier.height(8.dp))
      WavepointTextButton("RECONNECT SPOTIFY", onReconnect)
    }
    Spacer(Modifier.weight(1f))
  }
}

private data class BlockerCopy(
  val eyebrow: String,
  val title: String,
  val detail: String,
  val primary: String,
  val retryFirst: Boolean,
)
