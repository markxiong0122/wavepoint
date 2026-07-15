import SwiftUI

@MainActor
struct AppleMusicAppDependencies {
  let authorizer: any AppleMusicAuthorizing
  let selectionStore: any MusicProviderSelectionStoring
  let cleanupService: any CleanupLibraryServing
  let playerClient: any AppleMusicPlayerClient
}

@main
struct WavepointApp: App {
  private let providerModel: MusicProviderSessionModel?
  private let spotifyModel: AppSessionModel?
  private let spotifyCleanupModel: CleanupSessionModel?
  private let spotifyPlayback: SpotifyAppRemoteService?
  private let appleMusicCleanupModel: CleanupSessionModel?
  private let appleMusicPlayback: AppleMusicTrackPlayer?
  private let demoCleanupModel: CleanupSessionModel?
  private let startupError: String?

  init() {
    do {
      #if DEBUG && targetEnvironment(simulator)
        let demoScenario = AppleMusicSimulatorDemo.scenario(
          arguments: ProcessInfo.processInfo.arguments
        )
        let analytics: any AnalyticsCapturing =
          demoScenario == nil
          ? PostHogAnalytics.make()
          : NoOpAnalytics()
        let crashReporting: any CrashReporting =
          demoScenario == nil
          ? FirebaseCrashReporting.make()
          : NoOpCrashReporting()
      #else
        let analytics: any AnalyticsCapturing = PostHogAnalytics.make()
        let crashReporting: any CrashReporting = FirebaseCrashReporting.make()
      #endif

      analytics.capture(.appOpened)
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

      let appleMusicDependencies: AppleMusicAppDependencies
      #if DEBUG && targetEnvironment(simulator)
        if let demoScenario {
          appleMusicDependencies = AppleMusicSimulatorDemo.dependencies(for: demoScenario)
        } else {
          appleMusicDependencies = Self.realAppleMusicDependencies()
        }
      #else
        appleMusicDependencies = Self.realAppleMusicDependencies()
      #endif

      let providerModel = MusicProviderSessionModel(
        appleMusicAuthorizer: appleMusicDependencies.authorizer,
        selectionStore: appleMusicDependencies.selectionStore,
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

      let appleMusicCleanupModel = CleanupSessionModel(
        service: appleMusicDependencies.cleanupService,
        analytics: analytics,
        crashReporting: crashReporting
      )
      let appleMusicPlayback = AppleMusicTrackPlayer(
        client: appleMusicDependencies.playerClient
      )
      let demoCleanupModel = CleanupSessionModel(
        service: ReviewDemoLibraryService(),
        presentation: .demo
      )

      self.providerModel = providerModel
      self.spotifyModel = spotifyModel
      self.spotifyCleanupModel = spotifyCleanupModel
      self.spotifyPlayback = spotifyPlayback
      self.appleMusicCleanupModel = appleMusicCleanupModel
      self.appleMusicPlayback = appleMusicPlayback
      self.demoCleanupModel = demoCleanupModel
      self.startupError = nil
    } catch {
      providerModel = nil
      spotifyModel = nil
      spotifyCleanupModel = nil
      spotifyPlayback = nil
      appleMusicCleanupModel = nil
      appleMusicPlayback = nil
      demoCleanupModel = nil
      startupError = error.localizedDescription
    }
  }

  private static func realAppleMusicDependencies() -> AppleMusicAppDependencies {
    let songStore = MusicKitSongStore.shared
    let dumpsterService = AppleMusicDumpsterService(
      client: MusicKitPlaylistClient(songStore: songStore),
      store: UserDefaultsDumpsterPlaylistStore()
    )
    let service = AppleMusicLibraryService(
      client: MusicKitLibraryClient(songStore: songStore)
    ) { songIDs in
      try await dumpsterService.commit(songIDs: songIDs)
    }
    return AppleMusicAppDependencies(
      authorizer: MusicKitAuthorizationService(),
      selectionStore: UserDefaultsMusicProviderSelectionStore(),
      cleanupService: service,
      playerClient: SystemAppleMusicPlayerClient(songStore: songStore)
    )
  }

  var body: some Scene {
    WindowGroup {
      if let providerModel,
        let spotifyModel,
        let spotifyCleanupModel,
        let spotifyPlayback,
        let appleMusicCleanupModel,
        let appleMusicPlayback,
        let demoCleanupModel
      {
        AppRootView(
          providerModel: providerModel,
          spotifyModel: spotifyModel,
          spotifyCleanupModel: spotifyCleanupModel,
          spotifyPlayback: spotifyPlayback,
          appleMusicCleanupModel: appleMusicCleanupModel,
          appleMusicPlayback: appleMusicPlayback,
          demoCleanupModel: demoCleanupModel
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
