package ai.mapier.swipe.ui

import ai.mapier.swipe.cleanup.CleanupSummary
import ai.mapier.swipe.ui.theme.CutRecordMark
import ai.mapier.swipe.ui.theme.WavepointPalette
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun CleanupCompleteScreen(
  summary: CleanupSummary,
  onStartAgain: () -> Unit,
) {
  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(24.dp)
      .testTag("cleanup-complete"),
  ) {
    Spacer(Modifier.weight(1f))
    CutRecordMark(Modifier.size(96.dp))
    Spacer(Modifier.height(24.dp))
    Text(
      if (summary.decisionCount == 0) "Nothing buried." else "Clean cut.",
      color = WavepointPalette.Paper,
      fontWeight = FontWeight.Black,
      fontSize = 44.sp,
      letterSpacing = (-2).sp,
    )
    Spacer(Modifier.height(18.dp))
    Text(
      "${summary.decisionCount} DECIDED · ${summary.affectedCount} REMOVED",
      color = WavepointPalette.Keep,
      fontFamily = FontFamily.Monospace,
      fontWeight = FontWeight.Bold,
      fontSize = 13.sp,
    )
    Spacer(Modifier.height(28.dp))
    WavepointActionButton(
      label = "CLEAN ANOTHER BATCH",
      color = WavepointPalette.Keep,
      onClick = onStartAgain,
      modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.weight(1f))
  }
}
