import SwiftUI

@main
struct WavepointApp: App {
  private let sessionModel: AppSessionModel?
  private let startupError: String?

  init() {
    do {
      let configuration = try AppConfiguration.load()
      sessionModel = AppSessionModel(
        authenticator: try SupabaseSpotifyAuthenticator(configuration: configuration),
        tokenStore: KeychainSpotifyTokenStore()
      )
      startupError = nil
    } catch {
      sessionModel = nil
      startupError = error.localizedDescription
    }
  }

  var body: some Scene {
    WindowGroup {
      if let sessionModel {
        AppRootView(model: sessionModel)
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
