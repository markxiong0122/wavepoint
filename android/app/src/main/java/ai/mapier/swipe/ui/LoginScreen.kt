package ai.mapier.swipe.ui

import ai.mapier.swipe.ui.theme.CutRecordMark
import ai.mapier.swipe.ui.theme.WavepointPalette
import ai.mapier.swipe.ui.theme.WavepointShape
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
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
fun LoginScreen(onSignIn: () -> Unit) {
  Column(
    modifier = Modifier
      .fillMaxSize()
      .background(WavepointPalette.Paper)
      .padding(24.dp),
  ) {
    Row(verticalAlignment = Alignment.CenterVertically) {
      CutRecordMark(Modifier.size(52.dp))
      Column(Modifier.padding(start = 12.dp)) {
        Text("WAVEPOINT", fontWeight = FontWeight.Black, fontSize = 18.sp)
        Text(
          "LIKED SONGS CLEANER",
          fontFamily = FontFamily.Monospace,
          fontWeight = FontWeight.Bold,
          fontSize = 10.sp,
          letterSpacing = 1.1.sp,
        )
      }
    }

    Spacer(Modifier.weight(1f))
    Text(
      "A lighter\nlibrary, fast.",
      color = WavepointPalette.Ink,
      fontWeight = FontWeight.Black,
      fontSize = 52.sp,
      lineHeight = 48.sp,
      letterSpacing = (-2.4).sp,
    )
    Text(
      "Hear the songs buried in your Liked Songs. Swipe to keep or stage them for removal.",
      modifier = Modifier.padding(top = 24.dp),
      color = WavepointPalette.MutedInk,
      fontWeight = FontWeight.Medium,
      fontSize = 18.sp,
      lineHeight = 24.sp,
    )
    Spacer(Modifier.weight(1f))

    val shape = RoundedCornerShape(WavepointShape.ControlRadius.dp)
    Box(
      modifier = Modifier
        .fillMaxWidth()
        .height(60.dp),
    ) {
      Box(
        Modifier
          .matchParentSize()
          .padding(start = 5.dp, top = 5.dp)
          .background(WavepointPalette.Ink, shape),
      )
      Row(
        modifier = Modifier
          .fillMaxSize()
          .padding(end = 5.dp, bottom = 5.dp)
          .background(WavepointPalette.Keep, shape)
          .border(2.dp, WavepointPalette.Ink, shape)
          .clickable(onClick = onSignIn)
          .testTag("spotify-login-button")
          .padding(horizontal = 18.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Text(
          "CONTINUE WITH SPOTIFY",
          fontFamily = FontFamily.Monospace,
          fontWeight = FontWeight.Black,
          fontSize = 14.sp,
        )
        Text("↗", fontWeight = FontWeight.Black, fontSize = 20.sp)
      }
    }
    Text(
      "Spotify Premium required. Wavepoint reads and edits your Spotify library only after you confirm a removal batch.",
      modifier = Modifier.padding(top = 18.dp),
      color = WavepointPalette.MutedInk,
      fontFamily = FontFamily.Monospace,
      fontWeight = FontWeight.Medium,
      fontSize = 11.sp,
      lineHeight = 15.sp,
    )
  }
}
