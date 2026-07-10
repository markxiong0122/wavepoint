package ai.mapier.swipe.auth

import ai.mapier.swipe.spotify.SpotifyAccountEligibility
import ai.mapier.swipe.spotify.SpotifyAccountEligibilityChecker
import ai.mapier.swipe.spotify.SpotifyWebApiErrorKind
import ai.mapier.swipe.spotify.SpotifyWebApiException

data class SpotifyAuthSession(
  val supabaseAccessToken: String,
  val providerTokens: SpotifyProviderTokens?,
)

interface SpotifyAuthenticator {
  suspend fun restoreSession(): SpotifyAuthSession?
  suspend fun startSignIn()
  suspend fun signOut()
  suspend fun clearLocalSession()
}

enum class AppSessionState {
  RESTORING,
  SIGNED_OUT,
  AUTHORIZING,
  SIGNED_IN,
  SPOTIFY_PREMIUM_REQUIRED,
  SPOTIFY_RECONNECT_REQUIRED,
  SPOTIFY_ELIGIBILITY_UNAVAILABLE,
  FAILED,
}

class AppSession(
  private val authenticator: SpotifyAuthenticator,
  private val tokenStore: SpotifyTokenStoring,
  private val eligibilityChecker: SpotifyAccountEligibilityChecker? = null,
) {
  var state: AppSessionState = AppSessionState.RESTORING
    private set

  var errorMessage: String? = null
    private set

  suspend fun restore() {
    state = AppSessionState.RESTORING
    runCatching {
      val session = authenticator.restoreSession()
      if (session == null) {
        state = AppSessionState.SIGNED_OUT
        return
      }
      session.providerTokens?.let(tokenStore::save)
      if (tokenStore.load() != null) {
        verifyEligibility()
      } else {
        state = AppSessionState.SIGNED_OUT
      }
    }.onFailure(::fail)
  }

  suspend fun startSignIn() {
    state = AppSessionState.AUTHORIZING
    errorMessage = null
    runCatching { authenticator.startSignIn() }.onFailure(::fail)
  }

  suspend fun accept(session: SpotifyAuthSession) {
    val tokens = session.providerTokens
    if (tokens == null) {
      fail(IllegalStateException("Spotify did not return provider credentials."))
      return
    }
    tokenStore.save(tokens)
    errorMessage = null
    verifyEligibility()
  }

  fun reject(error: Throwable) {
    fail(error)
  }

  suspend fun signOut() {
    runCatching { authenticator.signOut() }
      .onSuccess {
        tokenStore.clear()
        errorMessage = null
        state = AppSessionState.SIGNED_OUT
      }
      .onFailure(::fail)
  }

  suspend fun retryEligibility() {
    if (tokenStore.load() == null) {
      state = AppSessionState.SIGNED_OUT
      return
    }
    verifyEligibility()
  }

  private suspend fun verifyEligibility() {
    val checker = eligibilityChecker
    if (checker == null) {
      state = AppSessionState.SIGNED_IN
      return
    }
    try {
      when (checker.fetchAccountEligibility()) {
        SpotifyAccountEligibility.PREMIUM -> state = AppSessionState.SIGNED_IN
        SpotifyAccountEligibility.FREE -> {
          authenticator.clearLocalSession()
          tokenStore.clear()
          state = AppSessionState.SPOTIFY_PREMIUM_REQUIRED
        }
        SpotifyAccountEligibility.UNVERIFIABLE ->
          state = AppSessionState.SPOTIFY_ELIGIBILITY_UNAVAILABLE
      }
    } catch (error: SpotifyWebApiException) {
      state = if (
        error.kind == SpotifyWebApiErrorKind.ACCOUNT_ELIGIBILITY_FORBIDDEN ||
        error.kind == SpotifyWebApiErrorKind.AUTHORIZATION_EXPIRED
      ) {
        AppSessionState.SPOTIFY_RECONNECT_REQUIRED
      } else {
        AppSessionState.SPOTIFY_ELIGIBILITY_UNAVAILABLE
      }
    } catch (_: Throwable) {
      state = AppSessionState.SPOTIFY_ELIGIBILITY_UNAVAILABLE
    }
  }

  private fun fail(error: Throwable) {
    errorMessage = error.message ?: "Spotify sign-in failed."
    state = AppSessionState.FAILED
  }
}
