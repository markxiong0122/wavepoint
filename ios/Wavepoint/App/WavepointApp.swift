import SwiftUI

@main
struct WavepointApp: App {
  private let providerModel: MusicProviderSessionModel?
  private let spotifyModel: AppSessionModel?
  private let spotifyCleanupModel: CleanupSessionModel?
  private let spotifyPlayback: SpotifyAppRemoteService?
  private let appleMusicCleanupModel: CleanupSessionModel?
  private let appleMusicPlayback: AppleMusicTrackPlayer?
  private let startupError: String?

  init() {
    do {
      let analytics = PostHogAnalytics.make()
      analytics.capture(.appOpened)
      let crashReporting = FirebaseCrashReporting.make()
      let configuration = try AppConfiguration.load()
      let tokenStore = KeychainSpotifyTokenStore()
      let supabaseClient = SupabaseSpotifyAuthenticator.makeClient(
        configuration: configuration
      )
      let credentialProvider = SpotifyCredentialProvider(
        tokenStore: tokenStore,
        refreshService: SupabaseSpotifyTokenRefreshService(
          client: supabaseClient,
          configuration: configuration
        )
      )
      let spotifyClient = SpotifyWebAPIClient { forceRefresh in
        try await credentialProvider.accessToken(forceRefresh: forceRefresh)
      }

      let providerModel = MusicProviderSessionModel(
        appleMusicAuthorizer: MusicKitAuthorizationService(),
        selectionStore: UserDefaultsMusicProviderSelectionStore(),
        analytics: analytics,
        crashReporting: crashReporting
      )
      let spotifyAuthenticator = try SupabaseSpotifyAuthenticator(
        client: supabaseClient,
        callbackURL: configuration.callbackURL
      )
      let spotifyModel = AppSessionModel(
        authenticator: spotifyAuthenticator,
        tokenStore: tokenStore,
        accountDeleter: SupabaseAccountDeletionService(
          client: supabaseClient,
          configuration: configuration
        ),
        eligibilityChecker: spotifyClient,
        analytics: analytics,
        crashReporting: crashReporting
      )
      let spotifyCleanupModel = CleanupSessionModel(
        service: spotifyClient,
        analytics: analytics,
        crashReporting: crashReporting
      )
      let spotifyPlayback = SpotifyAppRemoteService(
        client: SpotifySDKAppRemoteClient(
          clientID: configuration.spotifyClientID,
          callbackURL: configuration.spotifyAppRemoteCallbackURL
        ),
        accessToken: {
          try await credentialProvider.accessToken(forceRefresh: false)
        }
      )

      let songStore = MusicKitSongStore.shared
      let dumpsterService = AppleMusicDumpsterService(
        client: MusicKitPlaylistClient(songStore: songStore),
        store: UserDefaultsDumpsterPlaylistStore()
      )
      let appleMusicService = AppleMusicLibraryService(
        client: MusicKitLibraryClient(songStore: songStore)
      ) { songIDs in
        try await dumpsterService.commit(songIDs: songIDs)
      }
      let appleMusicCleanupModel = CleanupSessionModel(
        service: appleMusicService,
        analytics: analytics,
        crashReporting: crashReporting
      )
      let appleMusicPlayback = AppleMusicTrackPlayer(
        client: SystemAppleMusicPlayerClient(songStore: songStore)
      )

      self.providerModel = providerModel
      self.spotifyModel = spotifyModel
      self.spotifyCleanupModel = spotifyCleanupModel
      self.spotifyPlayback = spotifyPlayback
      self.appleMusicCleanupModel = appleMusicCleanupModel
      self.appleMusicPlayback = appleMusicPlayback
      self.startupError = nil
    } catch {
      providerModel = nil
      spotifyModel = nil
      spotifyCleanupModel = nil
      spotifyPlayback = nil
      appleMusicCleanupModel = nil
      appleMusicPlayback = nil
      startupError = error.localizedDescription
    }
  }

  var body: some Scene {
    WindowGroup {
      if let providerModel,
        let spotifyModel,
        let spotifyCleanupModel,
        let spotifyPlayback,
        let appleMusicCleanupModel,
        let appleMusicPlayback
      {
        AppRootView(
          providerModel: providerModel,
          spotifyModel: spotifyModel,
          spotifyCleanupModel: spotifyCleanupModel,
          spotifyPlayback: spotifyPlayback,
          appleMusicCleanupModel: appleMusicCleanupModel,
          appleMusicPlayback: appleMusicPlayback
        )
      } else {
        ConfigurationRequiredView(message: startupError ?? "App configuration is missing.")
      }
    }
  }
}

private struct ConfigurationRequiredView: View {
  let message: String

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      CutRecordMark(size: 72)
      Text("SETUP NEEDED")
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.remove)
      Text(message)
        .font(.system(size: 22, weight: .bold, design: .rounded))
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(WavepointTheme.paper)
    .background(WavepointTheme.darkSurface)
  }
}
