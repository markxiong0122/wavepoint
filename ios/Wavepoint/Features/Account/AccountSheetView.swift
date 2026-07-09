import SwiftUI

struct AccountSheetView: View {
  let onSignOut: () -> Void
  let onDeleteAccount: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var isConfirmingDeletion = false

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      Capsule()
        .fill(WavepointTheme.paper.opacity(0.28))
        .frame(width: 38, height: 5)
        .frame(maxWidth: .infinity)

      HStack(spacing: 12) {
        CutRecordMark(size: 48)
        VStack(alignment: .leading, spacing: 2) {
          Text("YOUR ACCOUNT")
            .font(.system(size: 20, weight: .black, design: .rounded))
          Text("WAVEPOINT × SPOTIFY")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(WavepointTheme.paper.opacity(0.62))
        }
      }

      Text("Wavepoint keeps your login identity in Supabase and Spotify credentials in this iPhone's Keychain. Your music library is read from Spotify and is not stored on Wavepoint servers.")
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(WavepointTheme.paper.opacity(0.78))

      Button {
        dismiss()
        onSignOut()
      } label: {
        accountButtonLabel("SIGN OUT", systemImage: "rectangle.portrait.and.arrow.right")
      }
      .buttonStyle(PressOffsetButtonStyle())

      Divider().overlay(WavepointTheme.paper.opacity(0.2))

      VStack(alignment: .leading, spacing: 9) {
        Text("DANGER ZONE")
          .font(.system(size: 10, weight: .black, design: .monospaced))
          .foregroundStyle(WavepointTheme.remove)

        Text("Deleting removes your Wavepoint account and local credentials. It does not delete your Spotify account or any songs.")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(WavepointTheme.paper.opacity(0.72))

        Button {
          isConfirmingDeletion = true
        } label: {
          accountButtonLabel(
            "DELETE ACCOUNT",
            systemImage: "trash",
            fill: WavepointTheme.remove
          )
        }
        .buttonStyle(PressOffsetButtonStyle())
      }

      Spacer(minLength: 0)
    }
    .padding(22)
    .foregroundStyle(WavepointTheme.paper)
    .background(WavepointTheme.darkSurface.ignoresSafeArea())
    .alert(
      "Delete your Wavepoint account?",
      isPresented: $isConfirmingDeletion
    ) {
      Button("DELETE WAVEPOINT ACCOUNT", role: .destructive) {
        dismiss()
        onDeleteAccount()
      }
      Button("CANCEL", role: .cancel) {}
    } message: {
      Text("This permanently deletes your Wavepoint login record and clears Spotify credentials from this iPhone. Your Spotify account and songs stay untouched.")
    }
  }

  private func accountButtonLabel(
    _ title: String,
    systemImage: String,
    fill: Color = WavepointTheme.paper
  ) -> some View {
    Label(title, systemImage: systemImage)
      .font(.system(size: 12, weight: .black, design: .monospaced))
      .frame(maxWidth: .infinity, minHeight: 52)
      .foregroundStyle(WavepointTheme.ink)
      .background(fill)
      .clipShape(RoundedRectangle(cornerRadius: WavepointTheme.controlRadius))
      .overlay {
        RoundedRectangle(cornerRadius: WavepointTheme.controlRadius)
          .stroke(WavepointTheme.ink, lineWidth: 2)
      }
  }
}
