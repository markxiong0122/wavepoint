import SwiftUI

@main
struct WavepointApp: App {
  private let sessionModel: AppSessionModel?
  private let cleanupModel: CleanupSessionModel?
  private let startupError: String?

  init() {
    do {
      let configuration = try AppConfiguration.load()
      let tokenStore = KeychainSpotifyTokenStore()
      let supabaseClient = SupabaseSpotifyAuthenticator.makeClient(
        configuration: configuration
      )
      sessionModel = AppSessionModel(
        authenticator: try SupabaseSpotifyAuthenticator(
          client: supabaseClient,
          callbackURL: configuration.callbackURL
        ),
        tokenStore: tokenStore
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
      cleanupModel = CleanupSessionModel(
        service: spotifyClient
      )
      startupError = nil
    } catch {
      sessionModel = nil
      cleanupModel = nil
      startupError = error.localizedDescription
    }
  }

  var body: some Scene {
    WindowGroup {
      if let sessionModel, let cleanupModel {
        AppRootView(model: sessionModel, cleanupModel: cleanupModel)
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
