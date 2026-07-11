import SwiftUI

struct TrackCardView: View {
  let track: LibraryTrack
  let position: Int
  let total: Int
  let previewPlayer: TrackPreviewPlayer
  let onRemove: () -> Void
  let onKeep: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dragOffset: CGSize = .zero
  @State private var isCommittingDecision = false

  var body: some View {
    GeometryReader { proxy in
      let layout = CleanupCardLayout(
        availableSize: proxy.size,
        detailHeight: 260,
        shadowDepth: 7
      )

      card(
        artworkHeight: layout.artworkHeight,
        detailHeight: layout.cardHeight - layout.artworkHeight
      )
        .frame(height: layout.cardHeight, alignment: .top)
        .overlay(alignment: dragOffset.width < 0 ? .topTrailing : .topLeading) {
          decisionStamp
        }
        .offset(dragOffset)
        .rotationEffect(.degrees(reduceMotion ? 0 : rotation(in: proxy.size.width)))
        .gesture(dragGesture(cardWidth: proxy.size.width))
        .padding(.bottom, layout.bottomClearance)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private func card(
    artworkHeight: CGFloat,
    detailHeight: CGFloat
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      artwork
        .frame(height: artworkHeight)

      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(savedDateLabel)
          Spacer()
          Text("\(position) / \(total)")
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.mutedInk)

        Text(track.title)
          .font(.system(size: 29, weight: .black, design: .rounded))
          .tracking(-1.1)
          .lineLimit(2, reservesSpace: true)
          .minimumScaleFactor(0.78)

        Text(track.artistLine)
          .font(.system(size: 16, weight: .semibold, design: .rounded))
          .foregroundStyle(WavepointTheme.mutedInk)
          .lineLimit(1)

        previewControl

        if let errorMessage = previewPlayer.errorMessage {
          Text(errorMessage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(WavepointTheme.remove)
            .lineLimit(1)
        }

        if let destinationURL = track.destinationURL {
          Link(destination: destinationURL) {
            Label(presentation.destinationActionTitle, systemImage: "arrow.up.right")
              .font(.system(size: 10, weight: .bold, design: .monospaced))
              .foregroundStyle(WavepointTheme.ink)
              .frame(minHeight: 32)
          }
          .accessibilityLabel("\(presentation.destinationActionTitle): \(track.title)")
        }
      }
      .padding(16)
      .frame(height: detailHeight, alignment: .top)
      .clipped()
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

  private var savedDateLabel: String {
    guard let addedAt = track.addedAt else { return "SAVED DATE UNKNOWN" }
    return "SAVED \(addedAt.formatted(.dateTime.year()))"
  }

  private var presentation: CleanupProviderPresentation {
    CleanupProviderPresentation(provider: track.provider)
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
      switch previewPlayer.source {
      case .spotifyRemote: "PLAY 15S IN SPOTIFY"
      case .appleMusic: "PLAY 15S IN MUSIC"
      case .directPreview: "PLAY 15S PREVIEW"
      case .unavailable: "PREVIEW UNAVAILABLE"
      }
    case .connecting:
      previewPlayer.source == .appleMusic
        ? "STARTING APPLE MUSIC…"
        : "CONNECTING TO SPOTIFY…"
    case .playing:
      switch previewPlayer.source {
      case .spotifyRemote: "PAUSE SPOTIFY"
      case .appleMusic: "PAUSE APPLE MUSIC"
      case .directPreview, .unavailable: "PAUSE PREVIEW"
      }
    case .paused:
      switch previewPlayer.source {
      case .spotifyRemote: "RESUME SPOTIFY"
      case .appleMusic: "RESUME APPLE MUSIC"
      case .directPreview, .unavailable: "RESUME PREVIEW"
      }
    }
  }

  @ViewBuilder
  private var decisionStamp: some View {
    if abs(dragOffset.width) > 64 {
      Text(dragOffset.width < 0 ? presentation.destructiveActionLabel : "✓ KEEP")
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
