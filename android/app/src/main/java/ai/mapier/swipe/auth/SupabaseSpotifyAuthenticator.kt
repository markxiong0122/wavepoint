package ai.mapier.swipe.auth

import android.content.Intent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.ExternalAuthAction
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.auth.SignOutScope
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.handleDeeplinks
import io.github.jan.supabase.auth.providers.Spotify
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions

class SupabaseSpotifyAuthenticator(
  private val client: SupabaseClient,
  private val request: SpotifyAuthorizationRequest = SpotifyAuthorizationRequest(),
) : SpotifyAuthenticator {
  override suspend fun restoreSession(): SpotifyAuthSession? {
    client.auth.awaitInitialization()
    return client.auth.currentSessionOrNull()?.toDomain()
  }

  override suspend fun startSignIn() {
    client.auth.signInWith(Spotify) {
      scopes.addAll(request.scopes)
    }
  }

  fun handleDeepLink(
    intent: Intent,
    onSession: (SpotifyAuthSession) -> Unit,
    onError: (Throwable) -> Unit,
  ) {
    client.handleDeeplinks(
      intent = intent,
      onSessionSuccess = { onSession(it.toDomain()) },
      onError = onError,
    )
  }

  override suspend fun signOut() {
    client.auth.signOut()
  }

  override suspend fun clearLocalSession() {
    client.auth.signOut(SignOutScope.LOCAL)
  }

  private fun UserSession.toDomain() = SpotifyAuthSession(
    supabaseAccessToken = accessToken,
    providerTokens = providerToken?.let { accessToken ->
      SpotifyProviderTokens(
        accessToken = accessToken,
        refreshToken = providerRefreshToken,
      )
    },
  )

  companion object {
    fun createClient(
      supabaseUrl: String,
      publishableKey: String,
      request: SpotifyAuthorizationRequest = SpotifyAuthorizationRequest(),
    ): SupabaseClient = createSupabaseClient(supabaseUrl, publishableKey) {
      install(Auth) {
        flowType = FlowType.PKCE
        scheme = request.callbackScheme
        host = request.callbackHost
        defaultExternalAuthAction = ExternalAuthAction.CustomTabs()
      }
      install(Functions)
    }
  }
}
