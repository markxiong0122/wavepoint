package ai.mapier.swipe.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SpotifyOAuthCallbackTest {
  @Test
  fun accessDeniedIsReportedAsACancelledSignIn() {
    var callbackError: Throwable? = null

    val handled = rejectSpotifyOAuthCallback(
      error = "access_denied",
      description = "The user denied access",
      onError = { callbackError = it },
    )

    assertTrue(handled)
    assertEquals("Spotify sign-in was cancelled.", callbackError?.message)
  }
}
