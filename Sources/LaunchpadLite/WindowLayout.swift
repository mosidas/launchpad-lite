import CoreGraphics

/// Cocoa 座標(主画面の左下原点、y 上向き)の矩形を AX 座標(主画面の左上原点、y 下向き)へ変換する。
func axFrame(fromCocoa rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
  CGRect(
    x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
}
