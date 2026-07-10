package ai.mapier.swipe.auth

data class SpotifyAuthorizationRequest(
  val callbackScheme: String = "ai.mapier.swipe",
  val callbackHost: String = "login-callback",
  val scopes: List<String> = listOf(
    "user-read-email",
    "user-read-private",
    "user-library-read",
    "user-library-modify",
    "user-read-recently-played",
    "app-remote-control",
  ),
)
