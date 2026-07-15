import SwiftUI

struct RemovalReviewView: View {
  let tracks: [LibraryTrack]
  let presentation: CleanupProviderPresentation
  let onCancel: () -> Void
  let onConfirm: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Button("← BACK", action: onCancel)
          .font(.system(size: 11, weight: .bold, design: .monospaced))
          .frame(minHeight: 44)
        Spacer()
        Text("REVIEW / \(tracks.count)")
          .font(.system(size: 11, weight: .bold, design: .monospaced))
      }

      Text("Ready to cut?")
        .font(.system(size: 38, weight: .black, design: .rounded))
        .tracking(-1.5)
      Text(presentation.reviewTrustCopy)
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(WavepointTheme.paper.opacity(0.68))

      ScrollView {
        LazyVStack(spacing: 10) {
          ForEach(tracks) { track in
            HStack(spacing: 12) {
              AsyncImage(url: track.artworkURL) { phase in
                if case .success(let image) = phase {
                  image.resizable().scaledToFill()
                } else {
                  ZStack {
                    WavepointTheme.midSurface
                    CutRecordMark(size: 36)
                  }
                }
              }
              .frame(width: 58, height: 58)
              .clipped()

              VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                  .font(.system(size: 15, weight: .bold, design: .rounded))
                  .lineLimit(1)
                Text(track.artistLine)
                  .font(.system(size: 12, weight: .medium, design: .rounded))
                  .foregroundStyle(WavepointTheme.mutedInk)
                  .lineLimit(1)
              }
              Spacer()
              Image(systemName: "xmark")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(WavepointTheme.remove)
            }
            .padding(10)
            .foregroundStyle(WavepointTheme.ink)
            .background(WavepointTheme.raisedPaper)
            .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.panelRadius))
          }
        }
      }

      Button(action: onConfirm) {
        Text(presentation.reviewActionTitle(count: tracks.count))
          .font(.system(size: 12, weight: .black, design: .monospaced))
          .frame(maxWidth: .infinity, minHeight: 56)
          .foregroundStyle(WavepointTheme.ink)
          .background(WavepointTheme.remove)
          .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))
          .overlay {
            RoundedRectangle(cornerRadius: WavepointTheme.controlRadius)
              .stroke(WavepointTheme.ink, lineWidth: 2)
          }
      }
      .buttonStyle(PressOffsetButtonStyle())
      .accessibilityLabel(presentation.reviewActionTitle(count: tracks.count))
    }
    .padding(20)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-review")
  }
}
