import SwiftUI

enum MusicProviderPickerOption: Equatable {
  case spotify
  case appleMusic
  case demo

  var title: String {
    switch self {
    case .spotify: "SPOTIFY · LIMITED BETA"
    case .appleMusic: "CONTINUE WITH APPLE MUSIC"
    case .demo: "TRY A DEMO CLEANUP"
    }
  }

  var disclosure: String {
    switch self {
    case .spotify:
      "Spotify Premium and tester access are currently required. Wavepoint can remove confirmed songs from Liked Songs."
    case .appleMusic:
      "Apple Music and Sync Library required. Tossed songs go to a Dumpster playlist and stay in your Library until you delete them in Music."
    case .demo:
      "Uses fictional songs and a local audio sample. Nothing connects to or changes a music library."
    }
  }

  var accessibilityIdentifier: String {
    switch self {
    case .spotify: "continue-with-spotify"
    case .appleMusic: "continue-with-apple-music"
    case .demo: "try-demo-cleanup"
    }
  }
}

struct MusicProviderPickerView: View {
  let onSelectSpotify: () -> Void
  let onSelectAppleMusic: () -> Void
  let onTryDemo: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 12) {
          CutRecordMark(size: 52)
          VStack(alignment: .leading, spacing: 2) {
            Text("WAVEPOINT")
              .font(.system(size: 18, weight: .black, design: .rounded))
            Text("MUSIC LIBRARY CLEANER")
              .font(.system(size: 10, weight: .semibold, design: .monospaced))
              .tracking(1.1)
          }
        }

        Text("A lighter\nlibrary, fast.")
          .font(.system(size: 52, weight: .black, design: .rounded))
          .tracking(-2.8)
          .lineSpacing(-8)
          .padding(.top, 48)
          .accessibilityAddTraits(.isHeader)

        Text(
          "Pick a music service. Hear the songs you buried, then swipe to keep or clean them up."
        )
        .font(.system(size: 18, weight: .medium, design: .rounded))
        .foregroundStyle(WavepointTheme.mutedInk)
        .lineSpacing(4)
        .padding(.top, 24)

        providerAction(.spotify, action: onSelectSpotify)
          .padding(.top, 42)
        providerAction(.appleMusic, action: onSelectAppleMusic)
          .padding(.top, 24)
        providerAction(.demo, action: onTryDemo)
          .padding(.top, 24)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 24)
    }
    .foregroundStyle(WavepointTheme.ink)
    .background(WavepointTheme.paper.ignoresSafeArea())
    .accessibilityIdentifier("music-provider-picker")
  }

  private func providerAction(
    _ option: MusicProviderPickerOption,
    action: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Button(action: action) {
        HStack {
          Text(option.title)
            .font(.system(size: 13, weight: .black, design: .monospaced))
          Spacer()
          Image(systemName: "arrow.right")
            .font(.system(size: 16, weight: .black))
        }
        .foregroundStyle(WavepointTheme.ink)
        .padding(.horizontal, 18)
        .frame(minHeight: 58)
        .background(actionColor(for: option))
        .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))
        .overlay {
          RoundedRectangle(cornerRadius: WavepointTheme.controlRadius)
            .stroke(WavepointTheme.ink, lineWidth: 2)
        }
        .background(alignment: .bottomTrailing) {
          RoundedRectangle(cornerRadius: WavepointTheme.controlRadius)
            .fill(WavepointTheme.ink)
            .offset(x: 5, y: 5)
        }
      }
      .buttonStyle(PressOffsetButtonStyle())
      .accessibilityIdentifier(option.accessibilityIdentifier)

      Text(option.disclosure)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(WavepointTheme.mutedInk)
        .lineSpacing(3)
    }
  }

  private func actionColor(for option: MusicProviderPickerOption) -> Color {
    switch option {
    case .spotify: WavepointTheme.keep
    case .appleMusic: WavepointTheme.audio
    case .demo: WavepointTheme.raisedPaper
    }
  }
}
