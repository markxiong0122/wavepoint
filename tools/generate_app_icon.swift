import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let canvasSize = 1024
let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.png")
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

guard let context = CGContext(
  data: nil,
  width: canvasSize,
  height: canvasSize,
  bitsPerComponent: 8,
  bytesPerRow: canvasSize * 4,
  space: colorSpace,
  bitmapInfo: bitmapInfo.rawValue
) else {
  fatalError("Unable to create an opaque drawing context")
}

let paper = CGColor(red: 0.957, green: 0.941, blue: 0.906, alpha: 1)
let ink = CGColor(red: 0.082, green: 0.082, blue: 0.075, alpha: 1)
let remove = CGColor(red: 1, green: 0.353, blue: 0.239, alpha: 1)
let keep = CGColor(red: 0.831, green: 1, blue: 0.388, alpha: 1)

context.setFillColor(paper)
context.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

context.setFillColor(ink)
context.fillEllipse(in: CGRect(x: 152, y: 152, width: 720, height: 720))

let wedge = CGMutablePath()
wedge.move(to: CGPoint(x: 512, y: 512))
wedge.addLine(to: CGPoint(x: 1024, y: 512))
wedge.addLine(to: CGPoint(x: 880, y: 1024))
wedge.closeSubpath()
context.addPath(wedge)
context.setFillColor(paper)
context.fillPath()

let labelRect = CGRect(x: 338, y: 338, width: 348, height: 348)
context.setFillColor(remove)
context.fillEllipse(in: labelRect)
context.setStrokeColor(paper)
context.setLineWidth(24)
context.strokeEllipse(in: labelRect.insetBy(dx: 12, dy: 12))

context.setFillColor(paper)
context.fillEllipse(in: CGRect(x: 470, y: 470, width: 84, height: 84))

context.setStrokeColor(keep)
context.setLineWidth(38)
context.setLineCap(.square)
context.move(to: CGPoint(x: 604, y: 512))
context.addLine(to: CGPoint(x: 840, y: 838))
context.strokePath()

guard let image = context.makeImage() else {
  fatalError("Unable to create app icon image")
}

guard image.alphaInfo == .noneSkipLast else {
  fatalError("App icon must not contain an alpha channel")
}

guard let destination = CGImageDestinationCreateWithURL(
  outputURL as CFURL,
  UTType.png.identifier as CFString,
  1,
  nil
) else {
  fatalError("Unable to create PNG destination")
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
  fatalError("Unable to encode app icon")
}
