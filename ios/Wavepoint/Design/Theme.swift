import SwiftUI

enum WavepointTheme {
  static let paper = Color(red: 0.957, green: 0.941, blue: 0.906)
  static let raisedPaper = Color(red: 1.0, green: 0.980, blue: 0.941)
  static let ink = Color(red: 0.082, green: 0.082, blue: 0.075)
  static let darkSurface = Color(red: 0.110, green: 0.106, blue: 0.094)
  static let midSurface = Color(red: 0.161, green: 0.157, blue: 0.141)
  static let mutedInk = Color(red: 0.404, green: 0.388, blue: 0.361)
  static let remove = Color(red: 1.0, green: 0.353, blue: 0.239)
  static let keep = Color(red: 0.831, green: 1.0, blue: 0.388)
  static let audio = Color(red: 0.467, green: 0.655, blue: 1.0)

  static let controlRadius: CGFloat = 6
  static let panelRadius: CGFloat = 14
  static let cardRadius: CGFloat = 19

  static func editorialFont(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
    .custom("AveriaSerifLibre-Bold", size: size, relativeTo: textStyle)
  }
}

struct CutRecordMark: View {
  var size: CGFloat = 76

  var body: some View {
    ZStack {
      Circle()
        .fill(WavepointTheme.ink)

      WedgeShape()
        .fill(WavepointTheme.paper)

      Circle()
        .fill(WavepointTheme.remove)
        .overlay {
          Circle().stroke(WavepointTheme.paper, lineWidth: size * 0.032)
        }
        .frame(width: size * 0.44)

      Circle()
        .fill(WavepointTheme.paper)
        .frame(width: size * 0.11)

      Path { path in
        path.move(to: CGPoint(x: size * 0.61, y: size * 0.5))
        path.addLine(to: CGPoint(x: size * 0.90, y: size * 0.12))
      }
      .stroke(
        WavepointTheme.keep,
        style: StrokeStyle(lineWidth: size * 0.045, lineCap: .square)
      )
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

private struct WedgeShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX * 0.86, y: rect.minY))
    path.closeSubpath()
    return path
  }
}

struct PressOffsetButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .offset(y: configuration.isPressed ? 3 : 0)
      .animation(
        .easeOut(duration: configuration.isPressed ? 0.12 : 0.07),
        value: configuration.isPressed
      )
  }
}
