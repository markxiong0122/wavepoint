package ai.mapier.swipe.auth

data class SpotifyAuthSession(
  val supabaseAccessToken: String,
  val providerTokens: SpotifyProviderTokens?,
)

interface SpotifyAuthenticator {
  suspend fun restoreSession(): SpotifyAuthSession?
  suspend fun startSignIn()
  suspend fun signOut()
}

enum class AppSessionState {
  RESTORING,
  SIGNED_OUT,
  AUTHORIZING,
  SIGNED_IN,
  FAILED,
}

class AppSession(
  private val authenticator: SpotifyAuthenticator,
  private val tokenStore: SpotifyTokenStoring,
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
      state = if (tokenStore.load() != null) {
        AppSessionState.SIGNED_IN
      } else {
        AppSessionState.SIGNED_OUT
      }
    }.onFailure(::fail)
  }

  suspend fun startSignIn() {
    state = AppSessionState.AUTHORIZING
    errorMessage = null
    runCatching { authenticator.startSignIn() }.onFailure(::fail)
  }

  fun accept(session: SpotifyAuthSession) {
    val tokens = session.providerTokens
    if (tokens == null) {
      fail(IllegalStateException("Spotify did not return provider credentials."))
      return
    }
    tokenStore.save(tokens)
    errorMessage = null
    state = AppSessionState.SIGNED_IN
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

  private fun fail(error: Throwable) {
    errorMessage = error.message ?: "Spotify sign-in failed."
    state = AppSessionState.FAILED
  }
}
