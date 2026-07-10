package ai.mapier.swipe.ui

import ai.mapier.swipe.ui.theme.CutRecordMark
import ai.mapier.swipe.ui.theme.WavepointPalette
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSheet(
  onDismiss: () -> Unit,
  onSignOut: () -> Unit,
  onDeleteAccount: () -> Unit,
) {
  var confirmsDeletion by remember { mutableStateOf(false) }

  ModalBottomSheet(
    onDismissRequest = onDismiss,
    containerColor = WavepointPalette.DarkSurface,
    contentColor = WavepointPalette.Paper,
    dragHandle = {
      Box(
        Modifier
          .padding(vertical = 12.dp)
          .size(width = 38.dp, height = 5.dp)
          .background(
            WavepointPalette.Paper.copy(alpha = 0.28f),
            RoundedCornerShape(50),
          ),
      )
    },
  ) {
    Column(
      modifier = Modifier.padding(start = 22.dp, end = 22.dp, bottom = 34.dp),
      verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
      Row(verticalAlignment = Alignment.CenterVertically) {
        CutRecordMark(Modifier.size(48.dp))
        Column(Modifier.padding(start = 12.dp)) {
          Text("YOUR ACCOUNT", fontWeight = FontWeight.Black, fontSize = 20.sp)
          Text(
            "WAVEPOINT × SPOTIFY",
            color = WavepointPalette.Paper.copy(alpha = 0.62f),
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 10.sp,
          )
        }
      }
      Text(
        "Wavepoint keeps your login identity in Supabase and Spotify credentials encrypted on this device. Your music library is read from Spotify and is not stored on Wavepoint servers.",
        color = WavepointPalette.Paper.copy(alpha = 0.78f),
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 20.sp,
      )
      WavepointActionButton(
        label = "SIGN OUT",
        color = WavepointPalette.Paper,
        onClick = onSignOut,
        modifier = Modifier.fillMaxWidth(),
      )
      HorizontalDivider(color = WavepointPalette.Paper.copy(alpha = 0.2f))
      Text(
        "DANGER ZONE",
        color = WavepointPalette.Remove,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Black,
        fontSize = 10.sp,
      )
      Text(
        "Deleting removes your Wavepoint account and local credentials. It does not delete your Spotify account or any songs.",
        color = WavepointPalette.Paper.copy(alpha = 0.72f),
        fontWeight = FontWeight.SemiBold,
        fontSize = 12.sp,
        lineHeight = 17.sp,
      )
      WavepointActionButton(
        label = "DELETE ACCOUNT",
        color = WavepointPalette.Remove,
        onClick = { confirmsDeletion = true },
        modifier = Modifier.fillMaxWidth(),
        tag = "delete-account-button",
      )
    }
  }

  if (confirmsDeletion) {
    AlertDialog(
      onDismissRequest = { confirmsDeletion = false },
      containerColor = WavepointPalette.DarkSurface,
      titleContentColor = WavepointPalette.Paper,
      textContentColor = WavepointPalette.Paper.copy(alpha = 0.76f),
      title = { Text("Delete your Wavepoint account?", fontWeight = FontWeight.Black) },
      text = {
        Text(
          "This permanently deletes your Wavepoint login record and clears Spotify credentials from this device. Your Spotify account and songs stay untouched.",
        )
      },
      confirmButton = {
        Text(
          "DELETE WAVEPOINT ACCOUNT",
          modifier = Modifier
            .clickable(onClick = onDeleteAccount)
            .testTag("confirm-account-deletion-button")
            .padding(12.dp),
          color = WavepointPalette.Remove,
          fontFamily = FontFamily.Monospace,
          fontWeight = FontWeight.Black,
          fontSize = 11.sp,
        )
      },
      dismissButton = {
        Text(
          "CANCEL",
          modifier = Modifier
            .clickable { confirmsDeletion = false }
            .padding(12.dp),
          color = WavepointPalette.Paper,
          fontFamily = FontFamily.Monospace,
          fontWeight = FontWeight.Bold,
          fontSize = 11.sp,
        )
      },
    )
  }
}
