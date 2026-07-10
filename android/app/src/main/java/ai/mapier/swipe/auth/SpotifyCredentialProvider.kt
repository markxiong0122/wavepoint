package ai.mapier.swipe.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.headersOf
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

data class RefreshedSpotifyToken(
  val accessToken: String,
  val refreshToken: String?,
  val expiresIn: Int,
)

interface SpotifyTokenRefreshService {
  suspend fun refresh(providerRefreshToken: String): RefreshedSpotifyToken
}

class SpotifyAuthorizationExpiredException : Exception("Spotify authorization expired")

class SpotifyCredentialProvider(
  private val tokenStore: SpotifyTokenStoring,
  private val refreshService: SpotifyTokenRefreshService,
) {
  suspend fun accessToken(forceRefresh: Boolean): String {
    val stored = tokenStore.load() ?: throw SpotifyAuthorizationExpiredException()
    if (!forceRefresh) return stored.accessToken
    val refreshToken = stored.refreshToken ?: throw SpotifyAuthorizationExpiredException()
    val refreshed = refreshService.refresh(refreshToken)
    tokenStore.save(
      SpotifyProviderTokens(
        accessToken = refreshed.accessToken,
        refreshToken = refreshed.refreshToken ?: refreshToken,
      ),
    )
    return refreshed.accessToken
  }
}

class SupabaseSpotifyTokenRefreshService(
  private val client: SupabaseClient,
  private val json: Json = Json { ignoreUnknownKeys = true },
) : SpotifyTokenRefreshService {
  override suspend fun refresh(providerRefreshToken: String): RefreshedSpotifyToken {
    val response = client.functions.invoke(
      function = "spotify-token-refresh",
      body = RefreshRequest(providerRefreshToken),
      headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString()),
    )
    val decoded = json.decodeFromString<RefreshResponse>(response.bodyAsText())
    return RefreshedSpotifyToken(
      accessToken = decoded.accessToken,
      refreshToken = decoded.refreshToken,
      expiresIn = decoded.expiresIn,
    )
  }
}

@Serializable
private data class RefreshRequest(
  @SerialName("refresh_token") val refreshToken: String,
)

@Serializable
private data class RefreshResponse(
  @SerialName("access_token") val accessToken: String,
  @SerialName("refresh_token") val refreshToken: String? = null,
  @SerialName("expires_in") val expiresIn: Int,
)
