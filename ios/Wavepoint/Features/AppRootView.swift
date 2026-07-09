import SwiftUI

struct AppRootView: View {
  var body: some View {
    ZStack {
      Color(red: 0.055, green: 0.052, blue: 0.049)
        .ignoresSafeArea()

      Text("Wavepoint")
        .font(.system(size: 34, weight: .black, design: .rounded))
        .foregroundStyle(Color(red: 0.96, green: 0.93, blue: 0.84))
    }
  }
}

#Preview {
  AppRootView()
}
