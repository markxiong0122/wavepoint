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

struct CleanupHomeView: View {
  @State private var model: CleanupSessionModel
  let onSignOut: () -> Void

  init(model: CleanupSessionModel, onSignOut: @escaping () -> Void) {
    _model = State(initialValue: model)
    self.onSignOut = onSignOut
  }

  var body: some View {
    Group {
      switch model.state {
      case .idle, .loading:
        loadingView
      case .deciding:
        deckView
      case .reviewing:
        RemovalReviewView(
          tracks: model.stagedRemovals,
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
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      CutRecordMark(size: 76)
      ProgressView()
        .tint(WavepointTheme.keep)
      Text("DIGGING THROUGH LIKED SONGS…")
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .tracking(0.7)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-loading")
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
      Button("SIGN OUT", action: onSignOut)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.paper.opacity(0.7))
        .frame(minHeight: 44)
    }
    .foregroundStyle(WavepointTheme.paper)
  }

  private var decisionControls: some View {
    HStack(spacing: 10) {
      decisionButton(
        title: "× REMOVE",
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
      Text("REMOVING \(model.stagedRemovals.count) SONGS…")
        .font(.system(size: 12, weight: .bold, design: .monospaced))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-committing")
  }

  private func errorView(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      CutRecordMark(size: 64)
      Text("SPOTIFY HIT A SNAG")
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

      Button("RECONNECT SPOTIFY", action: onSignOut)
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.paper)
        .frame(minHeight: 48)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-error")
  }
}
