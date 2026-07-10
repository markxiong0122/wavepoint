package ai.mapier.swipe.ui

import ai.mapier.swipe.cleanup.LibraryTrack
import ai.mapier.swipe.ui.theme.WavepointPalette
import ai.mapier.swipe.ui.theme.WavepointShape
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage

@Composable
fun RemovalReviewScreen(
  tracks: List<LibraryTrack>,
  onBack: () -> Unit,
  onConfirm: () -> Unit,
) {
  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(20.dp)
      .testTag("cleanup-review"),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    Row(
      Modifier.fillMaxWidth(),
      horizontalArrangement = Arrangement.SpaceBetween,
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Text(
        "← BACK",
        modifier = Modifier
          .height(44.dp)
          .clickable(onClick = onBack)
          .padding(top = 14.dp),
        color = WavepointPalette.Paper,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 11.sp,
      )
      Text(
        "REVIEW / ${tracks.size}",
        color = WavepointPalette.Paper,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 11.sp,
      )
    }
    Text(
      "Ready to cut?",
      color = WavepointPalette.Paper,
      fontWeight = FontWeight.Black,
      fontSize = 38.sp,
      letterSpacing = (-1.5).sp,
    )
    Text(
      "Nothing is removed until you confirm. Spotify will remove these songs from Liked Songs.",
      color = WavepointPalette.Paper.copy(alpha = 0.68f),
      fontWeight = FontWeight.Medium,
      fontSize = 15.sp,
      lineHeight = 20.sp,
    )
    LazyColumn(
      modifier = Modifier.weight(1f),
      verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
      items(tracks, key = LibraryTrack::id) { track -> ReviewTrack(track) }
    }
    WavepointActionButton(
      label = "REMOVE ${tracks.size} FROM LIKED SONGS",
      color = WavepointPalette.Remove,
      onClick = onConfirm,
      modifier = Modifier.fillMaxWidth(),
      tag = "confirm-removal-button",
    )
  }
}

@Composable
private fun ReviewTrack(track: LibraryTrack) {
  Row(
    modifier = Modifier
      .fillMaxWidth()
      .clip(RoundedCornerShape(WavepointShape.PanelRadius.dp))
      .background(WavepointPalette.RaisedPaper)
      .padding(10.dp),
    verticalAlignment = Alignment.CenterVertically,
    horizontalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    AsyncImage(
      model = track.artworkUrl,
      contentDescription = null,
      contentScale = ContentScale.Crop,
      modifier = Modifier
        .size(58.dp)
        .background(WavepointPalette.MidSurface),
    )
    Column(Modifier.weight(1f)) {
      Text(
        track.title,
        color = WavepointPalette.Ink,
        fontWeight = FontWeight.Bold,
        fontSize = 15.sp,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
      Spacer(Modifier.height(4.dp))
      Text(
        track.artistLine,
        color = WavepointPalette.MutedInk,
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
    }
    Text("×", color = WavepointPalette.Remove, fontWeight = FontWeight.Black, fontSize = 18.sp)
  }
}
