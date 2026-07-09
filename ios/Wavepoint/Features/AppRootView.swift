import SwiftUI

enum AppRootScreen: Equatable {
  case progress
  case login
  case cleanup
  case error(String)

  init(state: AppSessionState) {
    switch state {
    case .restoring, .authorizing, .deletingAccount:
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
  private let remotePlayback: SpotifyAppRemoteService

  init(
    model: AppSessionModel,
    cleanupModel: CleanupSessionModel,
    remotePlayback: SpotifyAppRemoteService
  ) {
    _model = State(initialValue: model)
    _cleanupModel = State(initialValue: cleanupModel)
    self.remotePlayback = remotePlayback
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
        CleanupHomeView(
          model: cleanupModel,
          remotePlayback: remotePlayback,
          onSignOut: {
            cleanupModel.reset()
            Task { await model.signOut() }
          },
          onDeleteAccount: {
            cleanupModel.reset()
            Task { await model.deleteAccount() }
          }
        )
      case .error(let message):
        authenticationError(message)
      }
    }
    .task {
      guard model.state == .restoring else { return }
      await model.restore()
    }
    .onOpenURL { url in
      Task { try? await remotePlayback.handleOpenURL(url) }
    }
    .alert(
      "ACCOUNT NOT DELETED",
      isPresented: Binding(
        get: { model.accountDeletionError != nil },
        set: { isPresented in
          if !isPresented { model.dismissAccountDeletionError() }
        }
      )
    ) {
      Button("OK") { model.dismissAccountDeletionError() }
    } message: {
      Text(model.accountDeletionError ?? "Please try again.")
    }
  }

  private var authenticationProgress: some View {
    VStack(spacing: 20) {
      CutRecordMark(size: 72)
      ProgressView()
        .tint(WavepointTheme.keep)
      Text(authenticationProgressLabel)
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .tracking(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(WavepointTheme.paper)
    .background(WavepointTheme.darkSurface)
    .accessibilityIdentifier("auth-progress")
  }

  private var authenticationProgressLabel: String {
    switch model.state {
    case .authorizing:
      "OPENING SPOTIFY…"
    case .deletingAccount:
      "DELETING ACCOUNT…"
    default:
      "RESTORING SESSION…"
    }
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
