import SwiftUI

struct CleanupPlaceholderView: View {
  let onSignOut: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      CutRecordMark(size: 92)
      Text("Spotify connected.")
        .font(.system(size: 34, weight: .black, design: .rounded))
      Text("Your cleanup deck is ready to load.")
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundStyle(WavepointTheme.mutedInk)
      Button("SIGN OUT", action: onSignOut)
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.ink)
        .padding(.horizontal, 20)
        .frame(minHeight: 48)
        .overlay {
          RoundedRectangle(cornerRadius: WavepointTheme.controlRadius)
            .stroke(WavepointTheme.ink, lineWidth: 2)
        }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(WavepointTheme.ink)
    .background(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-home")
  }
}
