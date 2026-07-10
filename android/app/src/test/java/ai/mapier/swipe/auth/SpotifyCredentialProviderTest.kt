package ai.mapier.swipe.auth

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class SpotifyCredentialProviderTest {
  @Test
  fun returnsStoredAccessTokenWithoutRefreshing() = runTest {
    val store = InMemorySpotifyTokenStore(
      SpotifyProviderTokens("stored-access", "refresh"),
    )
    val refresh = FakeSpotifyTokenRefreshService()
    val provider = SpotifyCredentialProvider(store, refresh)

    val token = provider.accessToken(forceRefresh = false)

    assertEquals("stored-access", token)
    assertEquals(0, refresh.callCount)
  }

  @Test
  fun forcedRefreshRotatesAndPersistsProviderTokens() = runTest {
    val store = InMemorySpotifyTokenStore(
      SpotifyProviderTokens("expired", "old-refresh"),
    )
    val refresh = FakeSpotifyTokenRefreshService(
      result = RefreshedSpotifyToken("new-access", "new-refresh", 3_600),
    )
    val provider = SpotifyCredentialProvider(store, refresh)

    val token = provider.accessToken(forceRefresh = true)

    assertEquals("new-access", token)
    assertEquals("old-refresh", refresh.lastRefreshToken)
    assertEquals(
      SpotifyProviderTokens("new-access", "new-refresh"),
      store.tokens,
    )
  }
}

private class FakeSpotifyTokenRefreshService(
  private val result: RefreshedSpotifyToken = RefreshedSpotifyToken("unused", null, 1),
) : SpotifyTokenRefreshService {
  var callCount = 0
  var lastRefreshToken: String? = null

  override suspend fun refresh(providerRefreshToken: String): RefreshedSpotifyToken {
    callCount += 1
    lastRefreshToken = providerRefreshToken
    return result
  }
}
