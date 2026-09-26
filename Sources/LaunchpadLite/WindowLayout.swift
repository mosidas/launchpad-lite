import CoreGraphics

/// Cocoa 座標(主画面の左下原点、y 上向き)の矩形を AX 座標(主画面の左上原点、y 下向き)へ変換する。
func axFrame(fromCocoa rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
  CGRect(
    x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
}

enum WindowAction {
  case leftHalf, rightHalf, topHalf, bottomHalf
  case topLeft, topRight, bottomLeft, bottomRight
  case maximize, centerThreeQuarters
}

/// action を適用したあとのウィンドウの矩形を返す。screen は可視領域で、AX 座標。
func targetFrame(_ action: WindowAction, screen: CGRect) -> CGRect {
  let halfW = screen.width / 2
  let halfH = screen.height / 2
  switch action {
  case .leftHalf:
    return CGRect(x: screen.minX, y: screen.minY, width: halfW, height: screen.height)
  case .rightHalf:
    return CGRect(x: screen.minX + halfW, y: screen.minY, width: halfW, height: screen.height)
  case .topHalf:
    return CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: halfH)
  case .bottomHalf:
    return CGRect(x: screen.minX, y: screen.minY + halfH, width: screen.width, height: halfH)
  case .topLeft:
    return CGRect(x: screen.minX, y: screen.minY, width: halfW, height: halfH)
  case .topRight:
    return CGRect(x: screen.minX + halfW, y: screen.minY, width: halfW, height: halfH)
  case .bottomLeft:
    return CGRect(x: screen.minX, y: screen.minY + halfH, width: halfW, height: halfH)
  case .bottomRight:
    return CGRect(x: screen.minX + halfW, y: screen.minY + halfH, width: halfW, height: halfH)
  case .maximize:
    return screen
  case .centerThreeQuarters:
    let w = screen.width * 3 / 4
    let h = screen.height * 3 / 4
    return CGRect(x: screen.midX - w / 2, y: screen.midY - h / 2, width: w, height: h)
  }
}

/// window の位置とサイズを、可視領域 from に対する比率のまま可視領域 to へ写す。
/// 結果は to の大きさを上限にし、はみ出した分は to の中へ押し戻す。すべて AX 座標。
func frameMoved(window: CGRect, from: CGRect, to: CGRect) -> CGRect {
  let w = min(window.width / from.width * to.width, to.width)
  let h = min(window.height / from.height * to.height, to.height)
  let x = to.minX + (window.minX - from.minX) / from.width * to.width
  let y = to.minY + (window.minY - from.minY) / from.height * to.height
  return CGRect(
    x: clamp(x, to.minX, to.maxX - w), y: clamp(y, to.minY, to.maxY - h), width: w, height: h)
}

/// v を lo...hi に収める。
private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
  max(lo, min(v, hi))
}
