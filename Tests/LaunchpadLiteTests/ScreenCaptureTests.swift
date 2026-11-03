import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import LaunchpadLite

@Test func selectionRectSpansBothPointsInEitherDirection() {
  let expected = CGRect(x: 200, y: 200, width: 300, height: 200)
  #expect(
    selectionRect(down: CGPoint(x: 200, y: 200), up: CGPoint(x: 500, y: 400)) == expected)
  #expect(
    selectionRect(down: CGPoint(x: 500, y: 400), up: CGPoint(x: 200, y: 200)) == expected)
}

private let observed = CGRect(x: 200, y: 200, width: 300, height: 200)

@Test func placementKeepsSelectionMatchingImageSize() {
  // 実測: (200,200)→(500,400) のドラッグで 602×402px(scale 2)の画像になる。
  #expect(
    placement(selection: observed, imagePixelSize: CGSize(width: 602, height: 402), scale: 2)
      == observed)
}

@Test func placementDropsSelectionNotMatchingImageSize() {
  #expect(
    placement(selection: observed, imagePixelSize: CGSize(width: 1464, height: 822), scale: 2)
      == nil)
  #expect(
    placement(selection: nil, imagePixelSize: CGSize(width: 602, height: 402), scale: 2) == nil)
  #expect(
    placement(selection: observed, imagePixelSize: CGSize(width: 602, height: 402), scale: 0)
      == nil)
}

/// 一時ディレクトリの中の、まだ無いファイルの URL。
private func temporaryURL() -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent(
    "LaunchpadLiteTests-\(UUID().uuidString).png")
}

/// 4×2px の PNG を url に書く。
private func writePNG(to url: URL) throws {
  let context = try #require(
    CGContext(
      data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
  context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
  let image = try #require(context.makeImage())
  let destination = try #require(
    CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
  CGImageDestinationAddImage(destination, image, nil)
  #expect(CGImageDestinationFinalize(destination), "PNG を書けた")
}

@Test func readCaptureReturnsNilWhenFileIsMissing() throws {
  #expect(try readCapture(from: temporaryURL(), selection: nil, scale: 2) == nil)
}

@Test func readCaptureRejectsNonImageFile() throws {
  let url = temporaryURL()
  defer { try? FileManager.default.removeItem(at: url) }
  try Data("not a png".utf8).write(to: url)
  let error = #expect(throws: CaptureError.self) {
    try readCapture(from: url, selection: nil, scale: 2)
  }
  guard case .unreadableImage = error else {
    Issue.record("unreadableImage でなく \(String(describing: error)) を投げた")
    return
  }
}

@Test func readCaptureDecodesImageAndValidatesSelection() throws {
  let url = temporaryURL()
  defer { try? FileManager.default.removeItem(at: url) }
  try writePNG(to: url)

  let matching = try #require(
    try readCapture(from: url, selection: CGRect(x: 0, y: 0, width: 2, height: 1), scale: 2))
  #expect(matching.image.width == 4)
  #expect(matching.image.height == 2)
  #expect(matching.selection == CGRect(x: 0, y: 0, width: 2, height: 1))

  let mismatched = try #require(
    try readCapture(from: url, selection: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 2))
  #expect(mismatched.selection == nil)
}

@Test func floatingFrameCoversSelectionInCocoaCoordinates() {
  #expect(
    floatingFrame(
      selection: CGRect(x: 100, y: 200, width: 300, height: 150),
      imagePixelSize: CGSize(width: 600, height: 300), primaryScreenHeight: 1000,
      mouseLocation: CGPoint(x: 0, y: 0), backingScaleFactor: 2)
      == CGRect(x: 100, y: 650, width: 300, height: 150))
}

@Test func floatingFrameTakesSizeFromImageAndTopLeftFromSelection() {
  // 両端を含むため画像は selection より 1pt 大きい。窓は画像の寸法に合わせ、左上を selection にそろえる。
  #expect(
    floatingFrame(
      selection: CGRect(x: 100, y: 200, width: 300, height: 150),
      imagePixelSize: CGSize(width: 602, height: 302), primaryScreenHeight: 1000,
      mouseLocation: CGPoint(x: 0, y: 0), backingScaleFactor: 2)
      == CGRect(x: 100, y: 1000 - 200 - 151, width: 301, height: 151))
}

@Test func floatingFrameCentersImageOnMouseWithoutSelection() {
  #expect(
    floatingFrame(
      selection: nil, imagePixelSize: CGSize(width: 600, height: 400), primaryScreenHeight: 1000,
      mouseLocation: CGPoint(x: 500, y: 500), backingScaleFactor: 2)
      == CGRect(x: 350, y: 400, width: 300, height: 200))
}
