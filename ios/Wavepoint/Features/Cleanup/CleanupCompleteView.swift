import SwiftUI

struct CleanupCompleteView: View {
  let summary: CleanupSummary
  let onStartAgain: () -> Void
  let onSignOut: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      CutRecordMark(size: 96)
      Text(presentation.completionTitle(hasDecisions: summary.decisionCount > 0))
        .font(.system(size: 44, weight: .black, design: .rounded))
        .tracking(-2)
      Text(
        presentation.completionStatLine(
          decisionCount: summary.decisionCount,
          affectedCount: summary.affectedCount
        )
      )
        .font(.system(size: 13, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.keep)

      if !presentation.completionInstructions.isEmpty {
        Text(presentation.completionInstructions)
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundStyle(WavepointTheme.paper.opacity(0.72))
      }

      if let destinationURL = summary.result.destinationURL {
        Link(presentation.destinationActionTitle, destination: destinationURL)
          .font(.system(size: 12, weight: .black, design: .monospaced))
          .foregroundStyle(WavepointTheme.audio)
          .frame(minHeight: 48)
      }

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

  private var presentation: CleanupProviderPresentation {
    CleanupProviderPresentation(provider: summary.provider)
  }
}
