import AppKit

/// アプリアイコンの絵に合わせたロケットのシルエット(右上 45° 向き、丸窓を抜く、フィン 2 枚、後端の炎)。
/// 縦向きの座標で描いてから回し、rect に収まるよう拡縮する。
func rocketPath(in rect: NSRect) -> NSBezierPath {
  let path = NSBezierPath()
  // 胴体(先端が +y)
  path.move(to: NSPoint(x: -3, y: -4))
  path.line(to: NSPoint(x: -3, y: 2))
  path.curve(
    to: NSPoint(x: 0, y: 9), controlPoint1: NSPoint(x: -3, y: 6),
    controlPoint2: NSPoint(x: -1.5, y: 8))
  path.curve(
    to: NSPoint(x: 3, y: 2), controlPoint1: NSPoint(x: 1.5, y: 8),
    controlPoint2: NSPoint(x: 3, y: 6))
  path.line(to: NSPoint(x: 3, y: -4))
  path.close()
  // フィン(胴体の後ろ寄りから斜め後方へ)
  for side: CGFloat in [-1, 1] {
    path.move(to: NSPoint(x: 3 * side, y: 0.5))
    path.curve(
      to: NSPoint(x: 6.5 * side, y: -5.5), controlPoint1: NSPoint(x: 5.5 * side, y: -0.5),
      controlPoint2: NSPoint(x: 6.5 * side, y: -3))
    path.line(to: NSPoint(x: 3 * side, y: -3.5))
    path.close()
  }
  // 炎(胴体の後端から離して置く)
  path.move(to: NSPoint(x: -1.8, y: -5))
  path.curve(
    to: NSPoint(x: 0, y: -9), controlPoint1: NSPoint(x: -1.8, y: -6.5),
    controlPoint2: NSPoint(x: -0.6, y: -7.5))
  path.curve(
    to: NSPoint(x: 1.8, y: -5), controlPoint1: NSPoint(x: 0.6, y: -7.5),
    controlPoint2: NSPoint(x: 1.8, y: -6.5))
  path.close()
  // 丸窓は偶奇規則で抜く(他の部品と重ならない位置に置く)
  path.appendOval(in: NSRect(x: -1.7, y: 1, width: 3.4, height: 3.4))
  path.windingRule = .evenOdd

  var turn = AffineTransform(rotationByDegrees: -45)
  path.transform(using: turn)
  let bounds = path.bounds
  let scale = min(rect.width / bounds.width, rect.height / bounds.height)
  turn = AffineTransform(translationByX: rect.midX, byY: rect.midY)
  turn.scale(scale)
  turn.translate(x: -bounds.midX, y: -bounds.midY)
  path.transform(using: turn)
  return path
}

/// メニューバー用の 18×18 pt のテンプレート画像。
@MainActor
func rocketTemplateImage() -> NSImage {
  let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
    NSColor.black.setFill()
    rocketPath(in: rect.insetBy(dx: 1, dy: 1)).fill()
    return true
  }
  image.isTemplate = true
  image.accessibilityDescription = "LaunchpadLite"
  return image
}
