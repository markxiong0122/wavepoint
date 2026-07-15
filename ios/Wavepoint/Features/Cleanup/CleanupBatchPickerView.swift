import SwiftUI

struct CleanupBatchPickerView: View {
  @Binding var selection: CleanupBatchSize
  let progress: CleanupLibraryLoadProgress?
  let onStart: () -> Void
  let headerActionTitle: String
  let onHeaderAction: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      header

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 7) {
            Text("Pick your cleanup run")
              .font(WavepointTheme.editorialFont(size: 34, relativeTo: .largeTitle))
              .fixedSize(horizontal: false, vertical: true)
            Text("Old saves get first dibs. You can stop and review whenever you want.")
              .font(.system(size: 14, weight: .medium, design: .rounded))
              .foregroundStyle(WavepointTheme.paper.opacity(0.68))
              .fixedSize(horizontal: false, vertical: true)
          }

          VStack(spacing: 11) {
            ForEach(CleanupBatchSize.allCases) { batch in
              batchButton(batch)
            }
          }

          scanProgress
        }
        .padding(.vertical, 18)
      }
      .scrollIndicators(.hidden)

      Button(action: onStart) {
        Text("START \(selection.title.uppercased()) · \(selection.songCount)")
          .font(.system(size: 13, weight: .black, design: .monospaced))
          .frame(maxWidth: .infinity, minHeight: 56)
          .foregroundStyle(WavepointTheme.ink)
          .background(WavepointTheme.keep)
          .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))
          .overlay {
            RoundedRectangle(cornerRadius: WavepointTheme.controlRadius)
              .stroke(WavepointTheme.ink, lineWidth: 2)
          }
      }
      .buttonStyle(PressOffsetButtonStyle())
      .padding(.bottom, 12)
      .accessibilityIdentifier("cleanup-batch-start")
    }
    .padding(.horizontal, 20)
    .foregroundStyle(WavepointTheme.paper)
    .accessibilityIdentifier("cleanup-batch-picker")
  }

  private var header: some View {
    HStack(spacing: 10) {
      CutRecordMark(size: 42)
      VStack(alignment: .leading, spacing: 1) {
        Text("WAVEPOINT")
          .font(.system(size: 15, weight: .black, design: .rounded))
        Text("CHOOSE YOUR DAMAGE")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .tracking(0.8)
      }
      Spacer()
      Button(headerActionTitle, action: onHeaderAction)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.paper.opacity(0.7))
        .frame(minHeight: 44)
    }
  }

  private func batchButton(_ batch: CleanupBatchSize) -> some View {
    let isSelected = selection == batch
    return Button {
      selection = batch
    } label: {
      HStack(spacing: 16) {
        Text(String(batch.songCount))
          .font(.system(size: 32, weight: .black, design: .monospaced))
          .frame(width: 58, alignment: .leading)

        VStack(alignment: .leading, spacing: 2) {
          Text(batch.title)
            .font(WavepointTheme.editorialFont(size: 25, relativeTo: .title2))
          Text(batch.detail.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.5)
            .opacity(0.68)
        }

        Spacer(minLength: 4)

        if batch.isRecommended {
          Text("SWEET SPOT")
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(isSelected ? WavepointTheme.ink : WavepointTheme.keep)
            .foregroundStyle(isSelected ? WavepointTheme.keep : WavepointTheme.ink)
            .clipShape(Capsule())
        }
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, minHeight: 86)
      .foregroundStyle(isSelected ? WavepointTheme.ink : WavepointTheme.paper)
      .background(isSelected ? WavepointTheme.keep : WavepointTheme.midSurface)
      .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.panelRadius))
      .overlay {
        RoundedRectangle(cornerRadius: WavepointTheme.panelRadius)
          .stroke(
            isSelected ? WavepointTheme.ink : WavepointTheme.paper.opacity(0.18),
            lineWidth: 2
          )
      }
    }
    .buttonStyle(PressOffsetButtonStyle())
    .accessibilityLabel("\(batch.title), \(batch.songCount) songs. \(batch.detail)")
    .accessibilityValue(isSelected ? "Selected" : "")
    .accessibilityIdentifier("cleanup-batch-\(batch.songCount)")
  }

  @ViewBuilder
  private var scanProgress: some View {
    if let progress, progress.totalCount > 0 {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(
            progress.loadedCount >= progress.totalCount
              ? "CRATE READY"
              : "DIGGING IN THE BACKGROUND"
          )
          Spacer()
          Text("\(progress.loadedCount) / \(progress.totalCount)")
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(WavepointTheme.paper.opacity(0.58))

        ProgressView(
          value: Double(progress.loadedCount),
          total: Double(max(progress.totalCount, 1))
        )
        .tint(WavepointTheme.audio)
      }
      .accessibilityElement(children: .combine)
    } else {
      HStack(spacing: 9) {
        ProgressView()
          .controlSize(.small)
          .tint(WavepointTheme.audio)
        Text("WARMING UP THE CRATE…")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(WavepointTheme.paper.opacity(0.58))
      }
    }
  }
}
