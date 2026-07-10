package ai.mapier.swipe.auth

import ai.mapier.swipe.spotify.SpotifyAccountEligibility
import ai.mapier.swipe.spotify.SpotifyAccountEligibilityChecker
import ai.mapier.swipe.spotify.SpotifyWebApiErrorKind
import ai.mapier.swipe.spotify.SpotifyWebApiException
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

  @Test
  fun freeAccountIsBlockedAndCredentialsAreCleared() = runTest {
    val tokenStore = InMemorySpotifyTokenStore()
    val authenticator = FakeSpotifyAuthenticator()
    val session = AppSession(
      authenticator,
      tokenStore,
      FakeEligibilityChecker(SpotifyAccountEligibility.FREE),
    )

    session.accept(
      SpotifyAuthSession(
        "supabase",
        SpotifyProviderTokens("access", "refresh"),
      ),
    )

    assertEquals(AppSessionState.SPOTIFY_PREMIUM_REQUIRED, session.state)
    assertNull(tokenStore.tokens)
    assertEquals(1, authenticator.clearLocalSessionCount)
  }

  @Test
  fun unknownProductKeepsCredentialsAndOffersRetry() = runTest {
    val tokenStore = InMemorySpotifyTokenStore()
    val session = AppSession(
      FakeSpotifyAuthenticator(),
      tokenStore,
      FakeEligibilityChecker(SpotifyAccountEligibility.UNVERIFIABLE),
    )

    session.accept(
      SpotifyAuthSession("supabase", SpotifyProviderTokens("access", "refresh")),
    )

    assertEquals(AppSessionState.SPOTIFY_ELIGIBILITY_UNAVAILABLE, session.state)
    assertEquals("access", tokenStore.tokens?.accessToken)
  }

  @Test
  fun forbiddenEligibilityShowsTesterReconnectState() = runTest {
    val session = AppSession(
      FakeSpotifyAuthenticator(),
      InMemorySpotifyTokenStore(),
      FakeEligibilityChecker(
        error = SpotifyWebApiException(SpotifyWebApiErrorKind.ACCOUNT_ELIGIBILITY_FORBIDDEN),
      ),
    )

    session.accept(
      SpotifyAuthSession("supabase", SpotifyProviderTokens("access", "refresh")),
    )

    assertEquals(AppSessionState.SPOTIFY_RECONNECT_REQUIRED, session.state)
  }
}

private class FakeSpotifyAuthenticator(
  private val restored: SpotifyAuthSession? = null,
) : SpotifyAuthenticator {
  var signOutCount = 0
  var clearLocalSessionCount = 0

  override suspend fun restoreSession(): SpotifyAuthSession? = restored

  override suspend fun startSignIn() = Unit

  override suspend fun signOut() {
    signOutCount += 1
  }

  override suspend fun clearLocalSession() {
    clearLocalSessionCount += 1
  }
}

private class FakeEligibilityChecker(
  private val result: SpotifyAccountEligibility? = null,
  private val error: Throwable? = null,
) : SpotifyAccountEligibilityChecker {
  override suspend fun fetchAccountEligibility(): SpotifyAccountEligibility {
    error?.let { throw it }
    return checkNotNull(result)
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
