package ai.mapier.swipe.ui

import ai.mapier.swipe.audio.SpotifyPlaybackState
import ai.mapier.swipe.cleanup.LibraryTrack
import ai.mapier.swipe.ui.theme.CutRecordMark
import ai.mapier.swipe.ui.theme.WavepointPalette
import ai.mapier.swipe.ui.theme.WavepointShape
import androidx.compose.animation.core.animate
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import java.time.ZoneOffset
import kotlin.math.abs
import kotlinx.coroutines.launch

@Composable
fun TrackCard(
  state: WavepointUiState.Deck,
  modifier: Modifier = Modifier,
  onRemove: () -> Unit,
  onKeep: () -> Unit,
  onPreview: () -> Unit,
  onOpenTrack: (String) -> Unit,
) {
  var offsetX by remember(state.track.id) { mutableFloatStateOf(0f) }
  var cardWidth by remember { mutableIntStateOf(1) }
  val scope = rememberCoroutineScope()
  val removes = offsetX < 0
  val shape = RoundedCornerShape(WavepointShape.CardRadius.dp)

  Box(
    modifier = modifier
      .testTag("track-card")
      .onSizeChanged { cardWidth = it.width.coerceAtLeast(1) }
      .graphicsLayer {
        translationX = offsetX
        rotationZ = (offsetX / cardWidth * 12f).coerceIn(-7f, 7f)
      }
      .pointerInput(state.track.id) {
        detectHorizontalDragGestures(
          onHorizontalDrag = { change, amount ->
            change.consume()
            offsetX += amount
          },
          onDragCancel = {
            scope.launch { animate(offsetX, 0f) { value, _ -> offsetX = value } }
          },
          onDragEnd = {
            val shouldCommit = abs(offsetX) >= cardWidth * 0.28f
            val removesTrack = offsetX < 0
            scope.launch {
              if (!shouldCommit) {
                animate(offsetX, 0f) { value, _ -> offsetX = value }
                return@launch
              }
              val destination = if (removesTrack) -cardWidth * 1.35f else cardWidth * 1.35f
              animate(offsetX, destination) { value, _ -> offsetX = value }
              if (removesTrack) onRemove() else onKeep()
            }
          },
        )
      },
  ) {
    Box(
      Modifier
        .fillMaxSize()
        .offset(x = 7.dp, y = 7.dp)
        .background(WavepointPalette.Remove, shape),
    )

    Column(
      modifier = Modifier
        .fillMaxSize()
        .padding(end = 7.dp, bottom = 7.dp)
        .clip(shape)
        .background(WavepointPalette.RaisedPaper)
        .border(2.dp, WavepointPalette.Ink, shape),
    ) {
      Artwork(state.track, Modifier.weight(1f))
      TrackDetails(
        state = state,
        onPreview = onPreview,
        onOpenTrack = onOpenTrack,
      )
    }

    if (abs(offsetX) > 64f) {
      Text(
        text = if (removes) "× REMOVE" else "✓ KEEP",
        modifier = Modifier
          .align(if (removes) Alignment.TopEnd else Alignment.TopStart)
          .padding(18.dp)
          .graphicsLayer { rotationZ = if (removes) 5f else -5f }
          .background(if (removes) WavepointPalette.Remove else WavepointPalette.Keep)
          .border(2.dp, WavepointPalette.Ink)
          .padding(horizontal = 12.dp, vertical = 10.dp),
        color = WavepointPalette.Ink,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Black,
        fontSize = 14.sp,
      )
    }
  }
}

@Composable
private fun Artwork(
  track: LibraryTrack,
  modifier: Modifier,
) {
  Box(
    modifier = modifier
      .fillMaxWidth()
      .background(WavepointPalette.MidSurface),
    contentAlignment = Alignment.Center,
  ) {
    if (track.artworkUrl == null) {
      CutRecordMark(Modifier.size(82.dp))
    } else {
      AsyncImage(
        model = track.artworkUrl,
        contentDescription = "Album artwork for ${track.title}",
        contentScale = ContentScale.Crop,
        modifier = Modifier
          .fillMaxSize()
          .testTag("track-artwork"),
      )
    }
  }
}

@Composable
private fun TrackDetails(
  state: WavepointUiState.Deck,
  onPreview: () -> Unit,
  onOpenTrack: (String) -> Unit,
) {
  val track = state.track
  Column(
    modifier = Modifier.padding(16.dp),
    verticalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(savedYear(track), style = cardMetaStyle())
      Text("${state.completedCount + 1} / ${state.totalCount}", style = cardMetaStyle())
    }
    Text(
      text = track.title,
      color = WavepointPalette.Ink,
      fontWeight = FontWeight.Black,
      fontSize = 28.sp,
      lineHeight = 29.sp,
      letterSpacing = (-1).sp,
      maxLines = 2,
      overflow = TextOverflow.Ellipsis,
    )
    Text(
      text = track.artistLine,
      color = WavepointPalette.MutedInk,
      fontWeight = FontWeight.SemiBold,
      fontSize = 16.sp,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
    )
    PreviewButton(
      state = state.playbackState,
      error = state.playbackError,
      onClick = onPreview,
    )
    track.destinationUrl?.let { destination ->
      Text(
        text = "↗  OPEN IN SPOTIFY",
        modifier = Modifier
          .height(32.dp)
          .clickable { onOpenTrack(destination) }
          .padding(top = 8.dp),
        color = WavepointPalette.Ink,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 10.sp,
      )
    }
  }
}

@Composable
private fun PreviewButton(
  state: SpotifyPlaybackState,
  error: String?,
  onClick: () -> Unit,
) {
  val label = when (state) {
    SpotifyPlaybackState.IDLE, SpotifyPlaybackState.READY -> "▶  PLAY 15S IN SPOTIFY"
    SpotifyPlaybackState.CONNECTING -> "…  CONNECTING TO SPOTIFY"
    SpotifyPlaybackState.PLAYING -> "Ⅱ  PAUSE SPOTIFY"
    SpotifyPlaybackState.APP_NOT_INSTALLED -> "↗  INSTALL SPOTIFY"
    SpotifyPlaybackState.AUTHORIZATION_REQUIRED -> "▶  AUTHORIZE SPOTIFY PLAYBACK"
    SpotifyPlaybackState.FAILED -> "↻  RETRY SPOTIFY PLAYBACK"
  }
  Column {
    Row(
      modifier = Modifier
        .fillMaxWidth()
        .height(42.dp)
        .clip(RoundedCornerShape(WavepointShape.ControlRadius.dp))
        .background(WavepointPalette.Audio.copy(alpha = 0.42f))
        .clickable(enabled = state != SpotifyPlaybackState.CONNECTING, onClick = onClick)
        .testTag("preview-button")
        .padding(horizontal = 10.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Text(
        label,
        color = WavepointPalette.Ink,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 10.sp,
      )
      Spacer(Modifier.weight(1f))
      if (state == SpotifyPlaybackState.CONNECTING || state == SpotifyPlaybackState.PLAYING) {
        CircularProgressIndicator(
          modifier = Modifier.size(16.dp),
          color = WavepointPalette.Audio,
          strokeWidth = 2.dp,
        )
      }
    }
    if (error != null) {
      Text(
        error,
        modifier = Modifier.padding(top = 6.dp),
        color = WavepointPalette.Remove,
        fontWeight = FontWeight.SemiBold,
        fontSize = 10.sp,
      )
    }
  }
}

private fun savedYear(track: LibraryTrack): String = track.addedAt
  ?.atZone(ZoneOffset.UTC)
  ?.year
  ?.let { "SAVED $it" }
  ?: "SAVED DATE UNKNOWN"

@Composable
private fun cardMetaStyle() = androidx.compose.ui.text.TextStyle(
  color = WavepointPalette.MutedInk,
  fontFamily = FontFamily.Monospace,
  fontWeight = FontWeight.Bold,
  fontSize = 10.sp,
)

@Composable
fun WavepointActionButton(
  label: String,
  color: Color,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
  tag: String? = null,
  enabled: Boolean = true,
) {
  val shape = RoundedCornerShape(WavepointShape.ControlRadius.dp)
  Box(
    modifier = modifier
      .height(54.dp)
      .clip(shape)
      .background(color.copy(alpha = if (enabled) 1f else 0.35f))
      .border(2.dp, WavepointPalette.Ink, shape)
      .clickable(enabled = enabled, onClick = onClick)
      .then(if (tag != null) Modifier.testTag(tag) else Modifier),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      label,
      color = WavepointPalette.Ink.copy(alpha = if (enabled) 1f else 0.55f),
      fontFamily = FontFamily.Monospace,
      fontWeight = FontWeight.Black,
      fontSize = 12.sp,
    )
  }
}

@Composable
fun WavepointTextButton(
  label: String,
  onClick: () -> Unit,
) {
  Box(
    modifier = Modifier
      .height(48.dp)
      .clickable(onClick = onClick)
      .padding(horizontal = 4.dp),
    contentAlignment = Alignment.CenterStart,
  ) {
    Text(
      label,
      color = WavepointPalette.Paper,
      fontFamily = FontFamily.Monospace,
      fontWeight = FontWeight.Bold,
      fontSize = 11.sp,
    )
  }
}
