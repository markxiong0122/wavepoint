import SwiftUI

enum CleanupScreen: Equatable {
  case loading
  case deck
  case review
  case committing
  case complete
  case error

  init(state: CleanupSessionState) {
    switch state {
    case .idle, .loading: self = .loading
    case .deciding: self = .deck
    case .reviewing: self = .review
    case .committing: self = .committing
    case .complete: self = .complete
    case .failed: self = .error
    }
  }

  var accessibilityIdentifier: String {
    switch self {
    case .loading: "cleanup-loading"
    case .deck: "cleanup-deck"
    case .review: "cleanup-review"
    case .committing: "cleanup-committing"
    case .complete: "cleanup-complete"
    case .error: "cleanup-error"
    }
  }
}

enum CleanupPlaybackScreen: Equatable {
  case starting
  case deck
  case failed(String)

  init(state: CleanupPlaybackState) {
    switch state {
    case .idle, .starting:
      self = .starting
    case .automatic, .manual:
      self = .deck
    case .failed(let message):
      self = .failed(message)
    }
  }
}

private enum CleanupSheet: String, Identifiable {
  case account

  var id: String { rawValue }
}

struct CleanupHomeView: View {
  @State private var model: CleanupSessionModel
  @State private var playback: CleanupPlaybackCoordinator
  @State private var presentedSheet: CleanupSheet?
  @State private var isConfirmingProviderChange = false
  let onSignOut: () -> Void
  let onDeleteAccount: () -> Void
  let onChangeProvider: () -> Void

  init(
    model: CleanupSessionModel,
    remotePlayback: any RemoteTrackPlaying,
    onSignOut: @escaping () -> Void,
    onDeleteAccount: @escaping () -> Void,
    onChangeProvider: @escaping () -> Void
  ) {
    _model = State(initialValue: model)
    _playback = State(
      initialValue: CleanupPlaybackCoordinator(
        player: TrackPreviewPlayer(remote: remotePlayback)
      )
    )
    self.onSignOut = onSignOut
    self.onDeleteAccount = onDeleteAccount
    self.onChangeProvider = onChangeProvider
  }

  var body: some View {
    Group {
      switch model.state {
      case .idle, .loading:
        loadingView
      case .deciding:
        playbackContent
      case .reviewing:
        RemovalReviewView(
          tracks: model.stagedRemovals,
          presentation: model.presentation,
          onCancel: model.cancelReview,
          onConfirm: { Task { await model.confirmRemovals() } }
        )
      case .committing:
        committingView
      case .complete(let summary):
        CleanupCompleteView(
          summary: summary,
          onStartAgain: { Task { await model.load() } },
          onSignOut: onSignOut
        )
      case .failed(let message):
        errorView(message)
      }
    }
    .background(WavepointTheme.darkSurface.ignoresSafeArea())
    .task {
      guard model.state == .idle else { return }
      await model.load()
    }
    .task(id: playbackTaskID) {
      guard model.state == .deciding, let track = model.currentTrack else {
        await playback.stop()
        return
      }
      await playback.present(track)
    }
    .onDisappear {
      Task { await playback.stop() }
    }
    .sheet(item: $presentedSheet) { sheet in
      switch sheet {
      case .account:
        AccountSheetView(
          provider: model.provider,
          onSignOut: onSignOut,
          onDeleteAccount: onDeleteAccount,
          onChangeProvider: requestProviderChange
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
      }
    }
    .alert("Leave this cleanup session?", isPresented: $isConfirmingProviderChange) {
      Button("CHANGE MUSIC SERVICE", role: .destructive, action: onChangeProvider)
      Button("KEEP CLEANING", role: .cancel) {}
    } message: {
      Text("Your decisions in this unconfirmed batch will be discarded.")
    }
  }

  @ViewBuilder
  private var playbackContent: some View {
    switch CleanupPlaybackScreen(state: playback.state) {
    case .starting:
      autoplayStartingView
    case .deck:
      deckView
    case .failed(let message):
      autoplayErrorView(message)
    }
  }

  private var playbackTaskID: String {
    let screen = CleanupScreen(state: model.state).accessibilityIdentifier
    return "\(screen):\(model.currentTrack?.id ?? "none")"
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      CutRecordMark(size: 76)
      ProgressView()
        .tint(WavepointTheme.keep)
      Text(model.presentation.loadingTitle)
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .tracking(0.7)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-loading")
  }

  private var autoplayStartingView: some View {
    VStack(spacing: 18) {
      CutRecordMark(size: 76)
      ProgressView()
        .tint(WavepointTheme.audio)
      Text("STARTING AUTOPLAY…")
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .tracking(0.7)
      Text(model.presentation.autoplayStartingDetail)
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(WavepointTheme.paper.opacity(0.68))
    }
    .multilineTextAlignment(.center)
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-autoplay-starting")
  }

  private var deckView: some View {
    VStack(spacing: 14) {
      cleanupHeader

      HStack {
        Text("\(model.completedCount) / \(model.totalCount) DECIDED")
        Spacer()
        Button("REVIEW \(model.stagedRemovals.count)") {
          model.beginReview()
        }
        .disabled(model.completedCount == 0)
      }
      .font(.system(size: 11, weight: .bold, design: .monospaced))
      .foregroundStyle(WavepointTheme.paper.opacity(0.72))

      ProgressView(value: Double(model.completedCount), total: Double(max(model.totalCount, 1)))
        .tint(WavepointTheme.keep)

      if let track = model.currentTrack {
        TrackCardView(
          track: track,
          position: model.completedCount + 1,
          total: model.totalCount,
          previewPlayer: playback.player,
          onRemove: model.removeCurrentTrack,
          onKeep: model.keepCurrentTrack
        )
        .id(track.id)
        .transition(.opacity.combined(with: .offset(y: 12)))
      }

      decisionControls
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .accessibilityIdentifier("cleanup-deck")
  }

  private var cleanupHeader: some View {
    HStack(spacing: 10) {
      CutRecordMark(size: 38)
      VStack(alignment: .leading, spacing: 1) {
        Text("WAVEPOINT")
          .font(.system(size: 15, weight: .black, design: .rounded))
        Text("CLEANUP SESSION")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .tracking(0.8)
      }
      Spacer()
      Button("ACCOUNT") {
        presentedSheet = .account
      }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.paper.opacity(0.7))
        .frame(minHeight: 44)
    }
    .foregroundStyle(WavepointTheme.paper)
  }

  private var decisionControls: some View {
    HStack(spacing: 10) {
      decisionButton(
        title: model.presentation.destructiveActionLabel,
        color: WavepointTheme.remove,
        action: model.removeCurrentTrack
      )

      Button(action: model.undo) {
        Image(systemName: "arrow.uturn.backward")
          .font(.system(size: 17, weight: .black))
          .frame(width: 52, height: 52)
          .foregroundStyle(WavepointTheme.paper)
          .overlay {
            RoundedRectangle(cornerRadius: WavepointTheme.controlRadius)
              .stroke(WavepointTheme.paper.opacity(0.45), lineWidth: 1)
          }
      }
      .disabled(model.completedCount == 0)
      .accessibilityLabel("Undo last decision")

      decisionButton(
        title: "✓ KEEP",
        color: WavepointTheme.keep,
        action: model.keepCurrentTrack
      )
    }
  }

  private func decisionButton(
    title: String,
    color: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .frame(maxWidth: .infinity, minHeight: 52)
        .foregroundStyle(WavepointTheme.ink)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))
        .overlay {
          RoundedRectangle(cornerRadius: WavepointTheme.controlRadius)
            .stroke(WavepointTheme.ink, lineWidth: 2)
        }
    }
    .buttonStyle(PressOffsetButtonStyle())
  }

  private var committingView: some View {
    VStack(spacing: 18) {
      ProgressView()
        .tint(WavepointTheme.remove)
      Text(model.presentation.committingTitle(count: model.stagedRemovals.count))
        .font(.system(size: 12, weight: .bold, design: .monospaced))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-committing")
  }

  private func autoplayErrorView(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      CutRecordMark(size: 64)
      Text("AUTOPLAY MISSED THE BEAT")
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .foregroundStyle(WavepointTheme.remove)
      Text(message)
        .font(.system(size: 22, weight: .bold, design: .rounded))

      Button("TRY AGAIN") {
        guard let track = model.currentTrack else { return }
        Task { await playback.retry(track) }
      }
      .font(.system(size: 12, weight: .black, design: .monospaced))
      .foregroundStyle(WavepointTheme.ink)
      .padding(.horizontal, 18)
      .frame(minHeight: 50)
      .background(WavepointTheme.keep)
      .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))

      Button("CONTINUE WITHOUT AUTOPLAY") {
        guard let track = model.currentTrack else { return }
        Task { await playback.continueManually(with: track) }
      }
      .font(.system(size: 11, weight: .bold, design: .monospaced))
      .foregroundStyle(WavepointTheme.paper)
      .frame(minHeight: 48)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-autoplay-error")
  }

  private func errorView(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      CutRecordMark(size: 64)
      Text(model.presentation.errorEyebrow)
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .foregroundStyle(WavepointTheme.remove)
      Text(message)
        .font(.system(size: 22, weight: .bold, design: .rounded))

      Button(model.stagedRemovals.isEmpty ? "TRY AGAIN" : "BACK TO REVIEW") {
        if model.stagedRemovals.isEmpty {
          Task { await model.load() }
        } else {
          model.returnToReview()
        }
      }
      .font(.system(size: 12, weight: .black, design: .monospaced))
      .foregroundStyle(WavepointTheme.ink)
      .padding(.horizontal, 18)
      .frame(minHeight: 50)
      .background(WavepointTheme.keep)
      .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))

      Button(
        model.provider == .spotify ? "RECONNECT SPOTIFY" : "CHANGE MUSIC SERVICE",
        action: model.provider == .spotify ? onSignOut : onChangeProvider
      )
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.paper)
        .frame(minHeight: 48)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-error")
  }

  private func requestProviderChange() {
    if model.requiresProviderChangeConfirmation {
      isConfirmingProviderChange = true
    } else {
      onChangeProvider()
    }
  }
}
