package ai.mapier.swipe.auth

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppSessionTest {
  @Test
  fun oauthCallbackCapturesProviderTokensAndSignsIn() = runTest {
    val tokenStore = InMemorySpotifyTokenStore()
    val session = AppSession(FakeSpotifyAuthenticator(), tokenStore)

    session.startSignIn()
    session.accept(
      SpotifyAuthSession(
        supabaseAccessToken = "supabase-token",
        providerTokens = SpotifyProviderTokens("provider-access", "provider-refresh"),
      ),
    )

    assertEquals(AppSessionState.SIGNED_IN, session.state)
    assertEquals(
      SpotifyProviderTokens("provider-access", "provider-refresh"),
      tokenStore.tokens,
    )
  }

  @Test
  fun restoreUsesEncryptedProviderTokensWhenSupabaseDropsThem() = runTest {
    val tokenStore = InMemorySpotifyTokenStore(
      SpotifyProviderTokens("stored-access", "stored-refresh"),
    )
    val authenticator = FakeSpotifyAuthenticator(
      restored = SpotifyAuthSession("supabase-token", providerTokens = null),
    )
    val session = AppSession(authenticator, tokenStore)

    session.restore()

    assertEquals(AppSessionState.SIGNED_IN, session.state)
  }

  @Test
  fun signOutClearsProviderCredentials() = runTest {
    val tokenStore = InMemorySpotifyTokenStore(
      SpotifyProviderTokens("stored-access", "stored-refresh"),
    )
    val authenticator = FakeSpotifyAuthenticator()
    val session = AppSession(authenticator, tokenStore)

    session.signOut()

    assertEquals(AppSessionState.SIGNED_OUT, session.state)
    assertNull(tokenStore.tokens)
    assertEquals(1, authenticator.signOutCount)
  }
}

private class FakeSpotifyAuthenticator(
  private val restored: SpotifyAuthSession? = null,
) : SpotifyAuthenticator {
  var signOutCount = 0

  override suspend fun restoreSession(): SpotifyAuthSession? = restored

  override suspend fun startSignIn() = Unit

  override suspend fun signOut() {
    signOutCount += 1
  }
}

internal class InMemorySpotifyTokenStore(
  var tokens: SpotifyProviderTokens? = null,
) : SpotifyTokenStoring {
  override fun save(tokens: SpotifyProviderTokens) {
    this.tokens = tokens
  }

  override fun load(): SpotifyProviderTokens? = tokens

  override fun clear() {
    tokens = null
  }
}
