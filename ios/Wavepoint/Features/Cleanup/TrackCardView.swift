import SwiftUI

struct TrackCardView: View {
  let track: SpotifyTrack
  let position: Int
  let total: Int
  let previewPlayer: TrackPreviewPlayer
  let showsSpotifyConnectionHint: Bool
  let onRemove: () -> Void
  let onKeep: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dragOffset: CGSize = .zero
  @State private var isCommittingDecision = false

  init(
    track: SpotifyTrack,
    position: Int,
    total: Int,
    previewPlayer: TrackPreviewPlayer,
    showsSpotifyConnectionHint: Bool,
    onRemove: @escaping () -> Void,
    onKeep: @escaping () -> Void
  ) {
    self.track = track
    self.position = position
    self.total = total
    self.previewPlayer = previewPlayer
    self.showsSpotifyConnectionHint = showsSpotifyConnectionHint
    self.onRemove = onRemove
    self.onKeep = onKeep
  }

  var body: some View {
    GeometryReader { proxy in
      card
        .overlay(alignment: dragOffset.width < 0 ? .topTrailing : .topLeading) {
          decisionStamp
        }
        .offset(dragOffset)
        .rotationEffect(.degrees(reduceMotion ? 0 : rotation(in: proxy.size.width)))
        .gesture(dragGesture(cardWidth: proxy.size.width))
    }
    .frame(maxHeight: .infinity)
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 0) {
      artwork

      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("SAVED \(track.addedAt.formatted(.dateTime.year()))")
          Spacer()
          Text("\(position) / \(total)")
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.mutedInk)

        Text(track.name)
          .font(.system(size: 29, weight: .black, design: .rounded))
          .tracking(-1.1)
          .lineLimit(2)
          .minimumScaleFactor(0.78)

        Text(track.artistLine)
          .font(.system(size: 16, weight: .semibold, design: .rounded))
          .foregroundStyle(WavepointTheme.mutedInk)
          .lineLimit(1)

        previewControl

        if showsSpotifyConnectionHint,
          previewPlayer.source == .spotifyRemote,
          previewPlayer.state == .ready
        {
          Text("Spotify may open once to connect.")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(WavepointTheme.mutedInk)
        }

        if let errorMessage = previewPlayer.errorMessage {
          Text(errorMessage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(WavepointTheme.remove)
        }

        Link(destination: track.spotifyURL) {
          Label("OPEN IN SPOTIFY", systemImage: "arrow.up.right")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(WavepointTheme.ink)
            .frame(minHeight: 32)
        }
        .accessibilityLabel("Open \(track.name) in Spotify")
      }
      .padding(16)
    }
    .background(WavepointTheme.raisedPaper)
    .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.cardRadius))
    .overlay {
      RoundedRectangle(cornerRadius: WavepointTheme.cardRadius)
        .stroke(WavepointTheme.ink, lineWidth: 2)
    }
    .background(alignment: .bottomTrailing) {
      RoundedRectangle(cornerRadius: WavepointTheme.cardRadius)
        .fill(WavepointTheme.remove)
        .offset(x: 7, y: 7)
    }
    .foregroundStyle(WavepointTheme.ink)
  }

  @ViewBuilder
  private var artwork: some View {
    if let url = track.artworkURL {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          TrackArtworkImage(image: image)
        case .failure:
          artworkPlaceholder
        default:
          ZStack {
            WavepointTheme.midSurface
            ProgressView().tint(WavepointTheme.keep)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
    } else {
      artworkPlaceholder
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var artworkPlaceholder: some View {
    ZStack {
      WavepointTheme.midSurface
      CutRecordMark(size: 82)
    }
  }

  private var previewControl: some View {
    Button {
      Task { await previewPlayer.togglePlayback() }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: previewIcon)
          .font(.system(size: 13, weight: .black))
        Text(previewLabel)
          .font(.system(size: 10, weight: .bold, design: .monospaced))
        Spacer()
        if previewPlayer.state == .playing || previewPlayer.state == .connecting {
          ProgressView()
            .tint(WavepointTheme.audio)
            .controlSize(.small)
        }
      }
      .foregroundStyle(
        previewPlayer.state == .unavailable
          ? WavepointTheme.mutedInk
          : WavepointTheme.ink
      )
      .padding(.horizontal, 10)
      .frame(minHeight: 40)
      .background(WavepointTheme.audio.opacity(previewPlayer.state == .unavailable ? 0.12 : 0.42))
      .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))
    }
    .disabled(previewPlayer.state == .unavailable)
    .accessibilityLabel(previewLabel)
  }

  private var previewIcon: String {
    switch previewPlayer.state {
    case .playing: "pause.fill"
    case .connecting: "ellipsis"
    case .unavailable: "waveform.slash"
    case .ready, .paused: "play.fill"
    }
  }

  private var previewLabel: String {
    switch previewPlayer.state {
    case .unavailable: "PREVIEW UNAVAILABLE"
    case .ready:
      previewPlayer.source == .spotifyRemote
        ? "PLAY 15S IN SPOTIFY"
        : "PLAY 15S PREVIEW"
    case .connecting: "CONNECTING TO SPOTIFY…"
    case .playing:
      previewPlayer.source == .spotifyRemote ? "PAUSE SPOTIFY" : "PAUSE PREVIEW"
    case .paused:
      previewPlayer.source == .spotifyRemote ? "RESUME SPOTIFY" : "RESUME PREVIEW"
    }
  }

  @ViewBuilder
  private var decisionStamp: some View {
    if abs(dragOffset.width) > 64 {
      Text(dragOffset.width < 0 ? "× REMOVE" : "✓ KEEP")
        .font(.system(size: 14, weight: .black, design: .monospaced))
        .foregroundStyle(WavepointTheme.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(dragOffset.width < 0 ? WavepointTheme.remove : WavepointTheme.keep)
        .overlay(Rectangle().stroke(WavepointTheme.ink, lineWidth: 2))
        .rotationEffect(.degrees(dragOffset.width < 0 ? 5 : -5))
        .padding(18)
        .transition(.opacity)
    }
  }

  private func rotation(in width: CGFloat) -> Double {
    Double(max(-7, min(7, dragOffset.width / width * 12)))
  }

  private func dragGesture(cardWidth: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        guard !isCommittingDecision else { return }
        dragOffset = value.translation
      }
      .onEnded { value in
        guard !isCommittingDecision else { return }
        let threshold = cardWidth * 0.28
        guard abs(value.translation.width) >= threshold else {
          withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.88)) {
            dragOffset = .zero
          }
          return
        }

        let removesTrack = value.translation.width < 0
        guard !reduceMotion else {
          if removesTrack {
            onRemove()
          } else {
            onKeep()
          }
          dragOffset = .zero
          return
        }

        isCommittingDecision = true
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)) {
          dragOffset.width = removesTrack ? -(cardWidth + 120) : cardWidth + 120
        }
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(150))
          if removesTrack {
            onRemove()
          } else {
            onKeep()
          }
        }
      }
  }
}

struct TrackArtworkImage: View {
  let image: Image

  var body: some View {
    image
      .resizable()
      .scaledToFill()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
  }
}
