import OSLog
import SwiftUI

enum AppRootScreen: Equatable {
  case progress
  case login
  case cleanup
  case spotifyPremiumRequired
  case spotifyReconnectRequired
  case spotifyEligibilityUnavailable
  case error(String)

  init(state: AppSessionState) {
    switch state {
    case .restoring, .authorizing, .deletingAccount:
      self = .progress
    case .signedOut:
      self = .login
    case .signedIn:
      self = .cleanup
    case .spotifyPremiumRequired:
      self = .spotifyPremiumRequired
    case .spotifyReconnectRequired:
      self = .spotifyReconnectRequired
    case .spotifyEligibilityUnavailable:
      self = .spotifyEligibilityUnavailable
    case .failed(let message):
      self = .error(message)
    }
  }

  var accessibilityIdentifier: String {
    switch self {
    case .progress: "auth-progress"
    case .login: "spotify-login-button"
    case .cleanup: "cleanup-home"
    case .spotifyPremiumRequired: "spotify-premium-required"
    case .spotifyReconnectRequired: "spotify-reconnect-required"
    case .spotifyEligibilityUnavailable: "spotify-eligibility-unavailable"
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
      case .spotifyPremiumRequired:
        spotifyBlocker(
          eyebrow: "SPOTIFY PREMIUM REQUIRED",
          message: "Wavepoint uses Spotify playback while you decide. Spotify Free accounts cannot start that playback.",
          primaryTitle: "TRY ANOTHER SPOTIFY ACCOUNT",
          identifier: "spotify-premium-required",
          primaryAction: { Task { await model.reconnect() } }
        )
      case .spotifyReconnectRequired:
        spotifyBlocker(
          eyebrow: "RECONNECT SPOTIFY",
          message: "Wavepoint could not verify this account. Reconnect with the latest permissions, or ask the app owner to add this account as a tester.",
          primaryTitle: "RECONNECT SPOTIFY",
          identifier: "spotify-reconnect-required",
          primaryAction: { Task { await model.reconnect() } }
        )
      case .spotifyEligibilityUnavailable:
        spotifyBlocker(
          eyebrow: "COULDN'T CHECK PREMIUM",
          message: "Spotify did not return a subscription status. Your connection is saved, so you can retry without signing in again.",
          primaryTitle: "TRY AGAIN",
          identifier: "spotify-eligibility-unavailable",
          primaryAction: { Task { await model.retryEligibility() } }
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
      Task {
        do {
          _ = try await remotePlayback.handleOpenURL(url)
        } catch {
          let nsError = error as NSError
          Logger(subsystem: "ai.mapier.swipe", category: "SpotifyAppRemote").error(
            "App Remote callback handling failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
          )
          #if DEBUG
            print(
              "[Wavepoint SpotifyAppRemote] Callback handling failed domain=\(nsError.domain) code=\(nsError.code)"
            )
          #endif
        }
      }
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

  private func spotifyBlocker(
    eyebrow: String,
    message: String,
    primaryTitle: String,
    identifier: String,
    primaryAction: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      CutRecordMark(size: 72)
      Text(eyebrow)
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .foregroundStyle(WavepointTheme.remove)
      Text(message)
        .font(.system(size: 22, weight: .bold, design: .rounded))
      Button(primaryTitle, action: primaryAction)
        .font(.system(size: 12, weight: .black, design: .monospaced))
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
    .accessibilityIdentifier(identifier)
  }
}
