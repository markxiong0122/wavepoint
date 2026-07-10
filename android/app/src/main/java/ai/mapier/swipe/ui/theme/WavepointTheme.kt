package ai.mapier.swipe.ui.theme

import androidx.compose.foundation.Canvas
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke

object WavepointPalette {
  val Paper = Color(0xFFF4F0E7)
  val RaisedPaper = Color(0xFFFFFAF0)
  val Ink = Color(0xFF151513)
  val DarkSurface = Color(0xFF1C1B18)
  val MidSurface = Color(0xFF292824)
  val MutedInk = Color(0xFF67635C)
  val Remove = Color(0xFFFF5A3D)
  val Keep = Color(0xFFD4FF63)
  val Audio = Color(0xFF77A7FF)
}

object WavepointShape {
  const val ControlRadius = 6
  const val PanelRadius = 14
  const val CardRadius = 19
}

private val colors = darkColorScheme(
  primary = WavepointPalette.Keep,
  secondary = WavepointPalette.Audio,
  error = WavepointPalette.Remove,
  background = WavepointPalette.DarkSurface,
  surface = WavepointPalette.DarkSurface,
  onPrimary = WavepointPalette.Ink,
  onBackground = WavepointPalette.Paper,
  onSurface = WavepointPalette.Paper,
)

@Composable
fun WavepointTheme(content: @Composable () -> Unit) {
  MaterialTheme(colorScheme = colors, content = content)
}

@Composable
fun CutRecordMark(modifier: Modifier = Modifier) {
  Canvas(modifier = modifier) {
    val diameter = size.minDimension
    val origin = Offset((size.width - diameter) / 2, (size.height - diameter) / 2)
    val center = origin + Offset(diameter / 2, diameter / 2)

    drawCircle(WavepointPalette.Ink, radius = diameter / 2, center = center)

    val wedge = Path().apply {
      moveTo(center.x, center.y)
      lineTo(origin.x + diameter, center.y)
      lineTo(origin.x + diameter * 0.86f, origin.y)
      close()
    }
    drawPath(wedge, WavepointPalette.Paper)

    drawCircle(WavepointPalette.Remove, radius = diameter * 0.22f, center = center)
    drawCircle(
      color = WavepointPalette.Paper,
      radius = diameter * 0.22f,
      center = center,
      style = Stroke(width = diameter * 0.032f),
    )
    drawCircle(WavepointPalette.Paper, radius = diameter * 0.055f, center = center)

    drawLine(
      color = WavepointPalette.Keep,
      start = Offset(origin.x + diameter * 0.61f, center.y),
      end = Offset(origin.x + diameter * 0.90f, origin.y + diameter * 0.12f),
      strokeWidth = diameter * 0.045f,
      cap = StrokeCap.Square,
    )
  }
}
