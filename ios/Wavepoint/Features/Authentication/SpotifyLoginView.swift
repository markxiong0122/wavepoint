import SwiftUI

struct SpotifyLoginView: View {
  let onSignIn: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        CutRecordMark(size: 52)
        VStack(alignment: .leading, spacing: 2) {
          Text("WAVEPOINT")
            .font(.system(size: 18, weight: .black, design: .rounded))
          Text("LIKED SONGS CLEANER")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.1)
        }
      }

      Spacer(minLength: 44)

      Text("A lighter\nlibrary, fast.")
        .font(.system(size: 54, weight: .black, design: .rounded))
        .tracking(-2.8)
        .lineSpacing(-8)
        .accessibilityAddTraits(.isHeader)

      Text("Hear the songs buried in your Liked Songs. Swipe to keep or stage them for removal.")
        .font(.system(size: 18, weight: .medium, design: .rounded))
        .foregroundStyle(WavepointTheme.mutedInk)
        .lineSpacing(4)
        .padding(.top, 24)

      Spacer(minLength: 40)

      Button(action: onSignIn) {
        HStack {
          Text("CONTINUE WITH SPOTIFY")
            .font(.system(size: 15, weight: .black, design: .monospaced))
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.system(size: 17, weight: .black))
        }
        .foregroundStyle(WavepointTheme.ink)
        .padding(.horizontal, 18)
        .frame(minHeight: 58)
        .background(WavepointTheme.keep)
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
      .accessibilityIdentifier("spotify-login-button")

      Text("Spotify Premium required. Wavepoint reads and edits your Spotify library only after you confirm a removal batch.")
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(WavepointTheme.mutedInk)
        .lineSpacing(3)
        .padding(.top, 20)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 24)
    .foregroundStyle(WavepointTheme.ink)
    .background(WavepointTheme.paper)
  }
}
