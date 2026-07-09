import SwiftUI

enum AppRootScreen: Equatable {
  case progress
  case login
  case cleanup
  case error(String)

  init(state: AppSessionState) {
    switch state {
    case .restoring, .authorizing:
      self = .progress
    case .signedOut:
      self = .login
    case .signedIn:
      self = .cleanup
    case .failed(let message):
      self = .error(message)
    }
  }

  var accessibilityIdentifier: String {
    switch self {
    case .progress: "auth-progress"
    case .login: "spotify-login-button"
    case .cleanup: "cleanup-home"
    case .error: "auth-error"
    }
  }
}

struct AppRootView: View {
  @State private var model: AppSessionModel
  @State private var cleanupModel: CleanupSessionModel

  init(model: AppSessionModel, cleanupModel: CleanupSessionModel) {
    _model = State(initialValue: model)
    _cleanupModel = State(initialValue: cleanupModel)
  }

  var body: some View {
    Group {
      switch AppRootScreen(state: model.state) {
      case .progress:
        authenticationProgress
      case .login:
        SpotifyLoginView {
          Task { await model.signIn() }
        }
      case .cleanup:
        CleanupHomeView(model: cleanupModel) {
          cleanupModel.reset()
          Task { await model.signOut() }
        }
      case .error(let message):
        authenticationError(message)
      }
    }
    .task {
      guard model.state == .restoring else { return }
      await model.restore()
    }
  }

  private var authenticationProgress: some View {
    VStack(spacing: 20) {
      CutRecordMark(size: 72)
      ProgressView()
        .tint(WavepointTheme.keep)
      Text(model.state == .authorizing ? "OPENING SPOTIFY…" : "RESTORING SESSION…")
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .tracking(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(WavepointTheme.paper)
    .background(WavepointTheme.darkSurface)
    .accessibilityIdentifier("auth-progress")
  }

  private func authenticationError(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("CONNECTION MISSED")
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.remove)
      Text(message)
        .font(.system(size: 22, weight: .bold, design: .rounded))
      Button("TRY AGAIN") {
        Task { await model.signIn() }
      }
      .font(.system(size: 13, weight: .black, design: .monospaced))
      .foregroundStyle(WavepointTheme.ink)
      .padding(.horizontal, 18)
      .frame(minHeight: 50)
      .background(WavepointTheme.keep)
      .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(WavepointTheme.paper)
    .background(WavepointTheme.darkSurface)
    .accessibilityIdentifier("auth-error")
  }
}
