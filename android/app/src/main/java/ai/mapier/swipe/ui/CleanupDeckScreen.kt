package ai.mapier.swipe.ui

import ai.mapier.swipe.ui.theme.CutRecordMark
import ai.mapier.swipe.ui.theme.WavepointPalette
import ai.mapier.swipe.ui.theme.WavepointShape
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun CleanupDeckScreen(
  state: WavepointUiState.Deck,
  actions: WavepointActions,
) {
  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(horizontal = 18.dp, vertical = 12.dp)
      .testTag("cleanup-deck"),
    verticalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    Header(onAccount = actions.onAccount)
    Row(
      Modifier.fillMaxWidth(),
      horizontalArrangement = Arrangement.SpaceBetween,
      verticalAlignment = Alignment.CenterVertically,
    ) {
      MetaText("${state.completedCount} / ${state.totalCount} DECIDED")
      Text(
        text = "REVIEW ${state.reviewCount}",
        modifier = Modifier
          .clickable(enabled = state.completedCount > 0, onClick = actions.onReview)
          .padding(vertical = 8.dp),
        color = WavepointPalette.Paper.copy(alpha = if (state.completedCount > 0) 0.72f else 0.32f),
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 11.sp,
      )
    }
    LinearProgressIndicator(
      progress = { state.completedCount.toFloat() / state.totalCount.coerceAtLeast(1) },
      modifier = Modifier
        .fillMaxWidth()
        .height(5.dp),
      color = WavepointPalette.Keep,
      trackColor = WavepointPalette.MidSurface,
    )
    TrackCard(
      state = state,
      modifier = Modifier
        .fillMaxWidth()
        .weight(1f),
      onRemove = actions.onRemove,
      onKeep = actions.onKeep,
      onPreview = actions.onPreview,
      onOpenTrack = actions.onOpenTrack,
    )
    Row(
      modifier = Modifier
        .fillMaxWidth()
        .height(54.dp),
      horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
      WavepointActionButton(
        label = "× REMOVE",
        color = WavepointPalette.Remove,
        onClick = actions.onRemove,
        modifier = Modifier.weight(1f),
        tag = "remove-button",
      )
      Box(
        modifier = Modifier
          .width(54.dp)
          .fillMaxSize()
          .border(
            1.dp,
            WavepointPalette.Paper.copy(alpha = if (state.completedCount > 0) 0.45f else 0.2f),
            RoundedCornerShape(WavepointShape.ControlRadius.dp),
          )
          .clickable(enabled = state.completedCount > 0, onClick = actions.onUndo)
          .testTag("undo-button"),
        contentAlignment = Alignment.Center,
      ) {
        Text(
          "↶",
          color = WavepointPalette.Paper.copy(alpha = if (state.completedCount > 0) 1f else 0.3f),
          fontWeight = FontWeight.Black,
          fontSize = 24.sp,
        )
      }
      WavepointActionButton(
        label = "✓ KEEP",
        color = WavepointPalette.Keep,
        onClick = actions.onKeep,
        modifier = Modifier.weight(1f),
        tag = "keep-button",
      )
    }
  }
}

@Composable
private fun Header(onAccount: () -> Unit) {
  Row(
    modifier = Modifier.fillMaxWidth(),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    CutRecordMark(Modifier.size(38.dp))
    Spacer(Modifier.width(10.dp))
    Column {
      Text(
        "WAVEPOINT",
        color = WavepointPalette.Paper,
        fontWeight = FontWeight.Black,
        fontSize = 15.sp,
      )
      Text(
        "CLEANUP SESSION",
        color = WavepointPalette.Paper,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 9.sp,
        letterSpacing = 0.8.sp,
      )
    }
    Spacer(Modifier.weight(1f))
    Text(
      "ACCOUNT",
      modifier = Modifier
        .height(44.dp)
        .clickable(onClick = onAccount)
        .padding(top = 15.dp),
      color = WavepointPalette.Paper.copy(alpha = 0.7f),
      fontFamily = FontFamily.Monospace,
      fontWeight = FontWeight.Bold,
      fontSize = 9.sp,
    )
  }
}

@Composable
private fun MetaText(text: String) {
  Text(
    text,
    color = WavepointPalette.Paper.copy(alpha = 0.72f),
    fontFamily = FontFamily.Monospace,
    fontWeight = FontWeight.Bold,
    fontSize = 11.sp,
  )
}
