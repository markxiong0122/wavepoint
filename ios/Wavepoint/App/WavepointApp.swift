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
      sessionModel = AppSessionModel(
        authenticator: try SupabaseSpotifyAuthenticator(configuration: configuration),
        tokenStore: tokenStore
      )
      let spotifyClient = SpotifyWebAPIClient {
        guard let accessToken = try tokenStore.load()?.accessToken else {
          throw SpotifyWebAPIError.authorizationExpired
        }
        return accessToken
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
