package ai.mapier.swipe.ui

import ai.mapier.swipe.audio.SpotifyPlaybackState
import ai.mapier.swipe.cleanup.CleanupSummary
import ai.mapier.swipe.cleanup.LibraryTrack
import ai.mapier.swipe.ui.theme.WavepointTheme
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class WavepointFlowTest {
  @get:Rule
  val composeRule = createComposeRule()

  @Test
  fun loginDisclosesPremiumBeforeStartingSpotify() {
    var signInCount = 0
    render(
      state = WavepointUiState.Login,
      actions = WavepointActions(onSignIn = { signInCount += 1 }),
    )

    composeRule.onNodeWithText("Spotify Premium required", substring = true)
      .assertIsDisplayed()
    composeRule.onNodeWithTag("spotify-login-button").performClick()

    assertEquals(1, signInCount)
  }

  @Test
  fun deckShowsProgressCropTargetAndSupportsSwipeRemove() {
    var removed = 0
    render(
      state = WavepointUiState.Deck(
        track = track("buried"),
        completedCount = 3,
        totalCount = 50,
        reviewCount = 2,
        playbackState = SpotifyPlaybackState.PLAYING,
      ),
      actions = WavepointActions(onRemove = { removed += 1 }),
    )

    composeRule.onNodeWithText("3 / 50 DECIDED").assertIsDisplayed()
    composeRule.onNodeWithText("REVIEW 2").assertIsEnabled()
    composeRule.onNodeWithTag("track-artwork").assertIsDisplayed()
    composeRule.onNodeWithTag("track-card").performTouchInput { swipeLeft() }
    composeRule.waitUntil(timeoutMillis = 2_000) { removed == 1 }
  }

  @Test
  fun missingSpotifyAppOffersInstallRecovery() {
    render(
      WavepointUiState.Deck(
        track = track("missing-app"),
        completedCount = 0,
        totalCount = 1,
        reviewCount = 0,
        playbackState = SpotifyPlaybackState.APP_NOT_INSTALLED,
      ),
    )
    composeRule.onNodeWithTag("preview-button").assertIsDisplayed()
    composeRule.onNodeWithText("↗  INSTALL SPOTIFY").assertIsDisplayed()
  }

  @Test
  fun missingPlaybackAuthorizationOffersAuthorizeRecovery() {
    render(
      WavepointUiState.Deck(
        track = track("needs-auth"),
        completedCount = 0,
        totalCount = 1,
        reviewCount = 0,
        playbackState = SpotifyPlaybackState.AUTHORIZATION_REQUIRED,
      ),
    )
    composeRule.onNodeWithTag("preview-button").assertIsDisplayed()
    composeRule.onNodeWithText("▶  AUTHORIZE SPOTIFY PLAYBACK").assertIsDisplayed()
  }

  @Test
  fun reviewIsAnExplicitDestructiveBoundary() {
    var confirmCount = 0
    render(
      state = WavepointUiState.Review(listOf(track("one"), track("two"))),
      actions = WavepointActions(onConfirmRemoval = { confirmCount += 1 }),
    )

    composeRule.onNodeWithText("Nothing is removed until you confirm.", substring = true)
      .assertIsDisplayed()
    composeRule.onNodeWithTag("confirm-removal-button").performClick()

    assertEquals(1, confirmCount)
  }

  @Test
  fun premiumBlockerExplainsWhyTheAccountCannotContinue() {
    render(WavepointUiState.Blocked(PremiumBlockerKind.PREMIUM_REQUIRED))
    composeRule.onNodeWithText("SPOTIFY PREMIUM REQUIRED").assertIsDisplayed()
  }

  @Test
  fun completionExplainsWhatHappened() {
    render(WavepointUiState.Complete(CleanupSummary(decisionCount = 12, affectedCount = 5)))
    composeRule.onNodeWithTag("cleanup-complete").assertIsDisplayed()
    composeRule.onNodeWithText("12 DECIDED · 5 REMOVED").assertIsDisplayed()
  }

  private fun render(
    state: WavepointUiState,
    actions: WavepointActions = WavepointActions(),
  ) {
    composeRule.setContent {
      WavepointTheme {
        WavepointApp(state = state, actions = actions)
      }
    }
  }

  private fun track(id: String) = LibraryTrack(
    id = id,
    playbackId = "spotify:track:$id",
    commitId = "spotify:track:$id",
    title = "Buried Song $id",
    artistNames = listOf("Artist One", "Artist Two"),
    artworkUrl = "https://example.com/$id.jpg",
    destinationUrl = "https://open.spotify.com/track/$id",
    durationMilliseconds = 180_000,
    addedAt = Instant.parse("2018-01-01T00:00:00Z"),
  )
}
