import OSLog
import SwiftUI
import UIKit

enum AppRootScreen: Equatable {
  case progress
  case providerPicker
  case login
  case cleanup(MusicProvider)
  case spotifyPremiumRequired
  case spotifyReconnectRequired
  case spotifyEligibilityUnavailable
  case appleMusicPermissionDenied
  case appleMusicRestricted
  case appleMusicPrivacyAcknowledgementRequired
  case appleMusicSubscriptionRequired
  case appleMusicSyncLibraryRequired
  case error(String)

  init(state: AppSessionState) {
    switch state {
    case .restoring, .authorizing, .deletingAccount:
      self = .progress
    case .signedOut:
      self = .login
    case .signedIn:
      self = .cleanup(.spotify)
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

  init(
    providerState: MusicProviderSessionState,
    spotifyState: AppSessionState
  ) {
    switch providerState {
    case .restoring, .authorizingAppleMusic:
      self = .progress
    case .providerPicker:
      self = .providerPicker
    case .spotifySelected:
      self.init(state: spotifyState)
    case .appleMusicReady:
      self = .cleanup(.appleMusic)
    case .appleMusicPermissionDenied:
      self = .appleMusicPermissionDenied
    case .appleMusicRestricted:
      self = .appleMusicRestricted
    case .appleMusicPrivacyAcknowledgementRequired:
      self = .appleMusicPrivacyAcknowledgementRequired
    case .appleMusicSubscriptionRequired:
      self = .appleMusicSubscriptionRequired
    case .appleMusicSyncLibraryRequired:
      self = .appleMusicSyncLibraryRequired
    case .failed(let message):
      self = .error(message)
    }
  }

  var accessibilityIdentifier: String {
    switch self {
    case .progress: "auth-progress"
    case .providerPicker: "music-provider-picker"
    case .login: "spotify-login-button"
    case .cleanup: "cleanup-home"
    case .spotifyPremiumRequired: "spotify-premium-required"
    case .spotifyReconnectRequired: "spotify-reconnect-required"
    case .spotifyEligibilityUnavailable: "spotify-eligibility-unavailable"
    case .appleMusicPermissionDenied: "apple-music-permission-denied"
    case .appleMusicRestricted: "apple-music-restricted"
    case .appleMusicPrivacyAcknowledgementRequired:
      "apple-music-privacy-acknowledgement-required"
    case .appleMusicSubscriptionRequired: "apple-music-subscription-required"
    case .appleMusicSyncLibraryRequired: "apple-music-sync-library-required"
    case .error: "auth-error"
    }
  }
}

struct AppRootView: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase

  @State private var providerModel: MusicProviderSessionModel
  @State private var spotifyModel: AppSessionModel
  @State private var spotifyCleanupModel: CleanupSessionModel
  @State private var appleMusicCleanupModel: CleanupSessionModel
  @State private var shouldStartSpotifySignIn = false

  private let spotifyPlayback: SpotifyAppRemoteService
  private let appleMusicPlayback: AppleMusicTrackPlayer

  init(
    providerModel: MusicProviderSessionModel,
    spotifyModel: AppSessionModel,
    spotifyCleanupModel: CleanupSessionModel,
    spotifyPlayback: SpotifyAppRemoteService,
    appleMusicCleanupModel: CleanupSessionModel,
    appleMusicPlayback: AppleMusicTrackPlayer
  ) {
    _providerModel = State(initialValue: providerModel)
    _spotifyModel = State(initialValue: spotifyModel)
    _spotifyCleanupModel = State(initialValue: spotifyCleanupModel)
    _appleMusicCleanupModel = State(initialValue: appleMusicCleanupModel)
    self.spotifyPlayback = spotifyPlayback
    self.appleMusicPlayback = appleMusicPlayback
  }

  var body: some View {
    Group {
      switch rootScreen {
      case .progress:
        authenticationProgress
      case .providerPicker:
        MusicProviderPickerView(
          onSelectSpotify: selectSpotify,
          onSelectAppleMusic: {
            Task { await providerModel.connectAppleMusic() }
          }
        )
      case .login:
        SpotifyLoginView(
          onSignIn: { Task { await spotifyModel.signIn() } },
          onChangeProvider: changeProvider
        )
      case .cleanup(let provider):
        cleanupView(provider: provider)
      case .spotifyPremiumRequired:
        connectionBlocker(
          eyebrow: "SPOTIFY PREMIUM REQUIRED",
          message: "Wavepoint uses Spotify playback while you decide. Spotify Free accounts cannot start that playback.",
          primaryTitle: "TRY ANOTHER SPOTIFY ACCOUNT",
          identifier: "spotify-premium-required",
          primaryAction: { Task { await spotifyModel.reconnect() } }
        )
      case .spotifyReconnectRequired:
        connectionBlocker(
          eyebrow: "RECONNECT SPOTIFY",
          message: "Wavepoint could not verify this account. Reconnect with the latest permissions, or ask the app owner to add this account as a tester.",
          primaryTitle: "RECONNECT SPOTIFY",
          identifier: "spotify-reconnect-required",
          primaryAction: { Task { await spotifyModel.reconnect() } }
        )
      case .spotifyEligibilityUnavailable:
        connectionBlocker(
          eyebrow: "COULDN'T CHECK PREMIUM",
          message: "Spotify did not return a subscription status. Your connection is saved, so you can retry without signing in again.",
          primaryTitle: "TRY AGAIN",
          identifier: "spotify-eligibility-unavailable",
          primaryAction: { Task { await spotifyModel.retryEligibility() } }
        )
      case .appleMusicPermissionDenied:
        connectionBlocker(
          eyebrow: "APPLE MUSIC ACCESS NEEDED",
          message: "Allow Media & Apple Music access in Settings so Wavepoint can read your library and build the Dumpster.",
          primaryTitle: "OPEN SETTINGS",
          identifier: "apple-music-permission-denied",
          primaryAction: openSettings
        )
      case .appleMusicRestricted:
        connectionBlocker(
          eyebrow: "APPLE MUSIC IS RESTRICTED",
          message: "This iPhone currently blocks Apple Music library access. Check Screen Time or device-management restrictions.",
          primaryTitle: "CHECK AGAIN",
          identifier: "apple-music-restricted",
          primaryAction: retryAppleMusic
        )
      case .appleMusicPrivacyAcknowledgementRequired:
        connectionBlocker(
          eyebrow: "FINISH SETTING UP APPLE MUSIC",
          message: "Open Music and accept Apple's privacy acknowledgement, then return to Wavepoint.",
          primaryTitle: "OPEN MUSIC",
          identifier: "apple-music-privacy-acknowledgement-required",
          primaryAction: openMusic
        )
      case .appleMusicSubscriptionRequired:
        connectionBlocker(
          eyebrow: "APPLE MUSIC REQUIRED",
          message: "Wavepoint needs an active Apple Music subscription to play cleanup tracks and build your Dumpster playlist.",
          primaryTitle: "CHECK AGAIN",
          identifier: "apple-music-subscription-required",
          primaryAction: retryAppleMusic
        )
      case .appleMusicSyncLibraryRequired:
        connectionBlocker(
          eyebrow: "TURN ON SYNC LIBRARY",
          message: "Enable Sync Library in Settings → Music, then return here so Wavepoint can see your full library.",
          primaryTitle: "CHECK AGAIN",
          identifier: "apple-music-sync-library-required",
          primaryAction: retryAppleMusic
        )
      case .error(let message):
        authenticationError(message)
      }
    }
    .task {
      guard providerModel.state == .restoring else { return }
      await providerModel.restore()
    }
    .task(id: providerModel.state) {
      guard providerModel.state == .spotifySelected else { return }
      if spotifyModel.state == .restoring {
        await spotifyModel.restore()
      }
      if shouldStartSpotifySignIn, spotifyModel.state == .signedOut {
        shouldStartSpotifySignIn = false
        await spotifyModel.signIn()
      }
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
      guard oldPhase != .active, newPhase == .active else { return }
      guard providerModel.state == .appleMusicPermissionDenied
        || providerModel.state == .appleMusicPrivacyAcknowledgementRequired
      else { return }
      retryAppleMusic()
    }
    .onOpenURL { url in
      Task {
        do {
          _ = try await spotifyPlayback.handleOpenURL(url)
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
        get: { spotifyModel.accountDeletionError != nil },
        set: { isPresented in
          if !isPresented { spotifyModel.dismissAccountDeletionError() }
        }
      )
    ) {
      Button("OK") { spotifyModel.dismissAccountDeletionError() }
    } message: {
      Text(spotifyModel.accountDeletionError ?? "Please try again.")
    }
  }

  private var rootScreen: AppRootScreen {
    AppRootScreen(
      providerState: providerModel.state,
      spotifyState: spotifyModel.state
    )
  }

  @ViewBuilder
  private func cleanupView(provider: MusicProvider) -> some View {
    switch provider {
    case .spotify:
      CleanupHomeView(
        model: spotifyCleanupModel,
        remotePlayback: spotifyPlayback,
        onSignOut: signOutSpotify,
        onDeleteAccount: deleteSpotifyAccount,
        onChangeProvider: changeProvider
      )
    case .appleMusic:
      CleanupHomeView(
        model: appleMusicCleanupModel,
        remotePlayback: appleMusicPlayback,
        onSignOut: changeProvider,
        onDeleteAccount: {},
        onChangeProvider: changeProvider
      )
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
    if providerModel.state == .authorizingAppleMusic {
      return "CONNECTING APPLE MUSIC…"
    }
    return switch spotifyModel.state {
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
      Button("TRY AGAIN", action: retryConnection)
        .font(.system(size: 13, weight: .black, design: .monospaced))
        .foregroundStyle(WavepointTheme.ink)
        .padding(.horizontal, 18)
        .frame(minHeight: 50)
        .background(WavepointTheme.keep)
        .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))
      Button("CHANGE MUSIC SERVICE", action: changeProvider)
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.paper)
        .frame(minHeight: 48)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(WavepointTheme.paper)
    .background(WavepointTheme.darkSurface)
    .accessibilityIdentifier("auth-error")
  }

  private func connectionBlocker(
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
      Button("CHANGE MUSIC SERVICE", action: changeProvider)
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.paper)
        .frame(minHeight: 48)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(WavepointTheme.paper)
    .background(WavepointTheme.darkSurface)
    .accessibilityIdentifier(identifier)
  }

  private func selectSpotify() {
    shouldStartSpotifySignIn = true
    providerModel.selectSpotify()
  }

  private func retryAppleMusic() {
    Task { await providerModel.retryAppleMusicEligibility() }
  }

  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    openURL(url)
  }

  private func openMusic() {
    guard let url = URL(string: "https://music.apple.com") else { return }
    openURL(url)
  }

  private func retryConnection() {
    Task {
      if case .failed = providerModel.state {
        await providerModel.restore()
      } else {
        await spotifyModel.signIn()
      }
    }
  }

  private func changeProvider() {
    spotifyCleanupModel.reset()
    appleMusicCleanupModel.reset()
    providerModel.clearSelection()
  }

  private func signOutSpotify() {
    spotifyCleanupModel.reset()
    Task {
      await spotifyModel.signOut()
      if spotifyModel.state == .signedOut {
        providerModel.clearSelection()
      }
    }
  }

  private func deleteSpotifyAccount() {
    spotifyCleanupModel.reset()
    Task {
      await spotifyModel.deleteAccount()
      if spotifyModel.state == .signedOut {
        providerModel.clearSelection()
      }
    }
  }
}
