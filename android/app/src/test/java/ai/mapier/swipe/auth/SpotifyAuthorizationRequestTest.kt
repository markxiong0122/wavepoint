package ai.mapier.swipe.auth

import org.junit.Assert.assertEquals
import org.junit.Test

class SpotifyAuthorizationRequestTest {
  @Test
  fun requestUsesPkceCallbackAndEveryRequiredScope() {
    val request = SpotifyAuthorizationRequest()

    assertEquals("ai.mapier.swipe", request.callbackScheme)
    assertEquals("login-callback", request.callbackHost)
    assertEquals(
      listOf(
        "user-read-email",
        "user-read-private",
        "user-library-read",
        "user-library-modify",
        "user-read-recently-played",
        "app-remote-control",
      ),
      request.scopes,
    )
  }
}
