package ai.mapier.swipe.auth

data class SpotifyProviderTokens(
  val accessToken: String,
  val refreshToken: String?,
)

interface SpotifyTokenStoring {
  fun save(tokens: SpotifyProviderTokens)
  fun load(): SpotifyProviderTokens?
  fun clear()
}
