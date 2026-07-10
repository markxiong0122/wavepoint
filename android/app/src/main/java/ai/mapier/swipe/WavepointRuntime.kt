package ai.mapier.swipe

import ai.mapier.swipe.audio.CoroutinePreviewScheduler
import ai.mapier.swipe.audio.SpotifyAppRemotePlayer
import ai.mapier.swipe.audio.SpotifySdkRemoteGateway
import ai.mapier.swipe.auth.AndroidKeystoreTokenCipherBox
import ai.mapier.swipe.auth.AppSession
import ai.mapier.swipe.auth.SharedPreferencesTokenKeyValueStore
import ai.mapier.swipe.auth.SpotifyCredentialProvider
import ai.mapier.swipe.auth.SpotifyTokenStore
import ai.mapier.swipe.auth.SupabaseSpotifyAuthenticator
import ai.mapier.swipe.auth.SupabaseSpotifyTokenRefreshService
import ai.mapier.swipe.cleanup.CleanupDeckBuilder
import ai.mapier.swipe.cleanup.CleanupSession
import ai.mapier.swipe.spotify.SpotifyWebApiClient
import ai.mapier.swipe.ui.WavepointController
import android.content.Context
import kotlinx.coroutines.CoroutineScope

data class WavepointRuntime(
  val controller: WavepointController,
  val authenticator: SupabaseSpotifyAuthenticator,
) {
  companion object {
    fun create(
      context: Context,
      scope: CoroutineScope,
    ): WavepointRuntime {
      val supabase = SupabaseSpotifyAuthenticator.createClient(
        supabaseUrl = BuildConfig.SUPABASE_URL,
        publishableKey = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
      )
      val authenticator = SupabaseSpotifyAuthenticator(supabase)
      val tokenStore = SpotifyTokenStore(
        values = SharedPreferencesTokenKeyValueStore(context),
        cipherBox = AndroidKeystoreTokenCipherBox(),
      )
      val credentials = SpotifyCredentialProvider(
        tokenStore = tokenStore,
        refreshService = SupabaseSpotifyTokenRefreshService(supabase),
      )
      val spotify = SpotifyWebApiClient { forceRefresh ->
        credentials.accessToken(forceRefresh)
      }
      val player = SpotifyAppRemotePlayer(
        gateway = SpotifySdkRemoteGateway(
          context = context,
          clientId = BuildConfig.SPOTIFY_CLIENT_ID,
          redirectUri = BuildConfig.SPOTIFY_APP_REMOTE_REDIRECT_URI,
        ),
        scheduler = CoroutinePreviewScheduler(scope),
      )
      val controller = WavepointController(
        appSession = AppSession(
          authenticator = authenticator,
          tokenStore = tokenStore,
          eligibilityChecker = spotify,
        ),
        library = spotify,
        cleanupSession = CleanupSession(),
        deckBuilder = CleanupDeckBuilder(),
        player = player,
        scope = scope,
      )
      return WavepointRuntime(controller, authenticator)
    }
  }
}
