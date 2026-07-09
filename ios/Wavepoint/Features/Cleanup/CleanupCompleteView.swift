import SwiftUI

struct CleanupCompleteView: View {
  let summary: CleanupSummary
  let onStartAgain: () -> Void
  let onSignOut: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      CutRecordMark(size: 96)
      Text(summary.decisionCount == 0 ? "Nothing to clean." : "That feels lighter.")
        .font(.system(size: 44, weight: .black, design: .rounded))
        .tracking(-2)
      Text("\(summary.decisionCount) decided  ·  \(summary.removedCount) removed")
        .font(.system(size: 13, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.keep)

      Button("CLEAN ANOTHER BATCH", action: onStartAgain)
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .foregroundStyle(WavepointTheme.ink)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(WavepointTheme.keep)
        .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))

      Button("SIGN OUT", action: onSignOut)
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .frame(minHeight: 48)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-complete")
  }
}
