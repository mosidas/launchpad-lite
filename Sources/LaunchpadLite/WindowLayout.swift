import CoreGraphics

/// Cocoa 座標(主画面の左下原点、y 上向き)の矩形を AX 座標(主画面の左上原点、y 下向き)へ変換する。
func axFrame(fromCocoa rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
  CGRect(
    x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
}

enum WindowAction {
  case leftHalf, rightHalf, topHalf, bottomHalf, maximize, center
  case widen, narrow, taller, shorter
  case moveLeft, moveRight, moveUp, moveDown
}

/// action を適用したあとのウィンドウの矩形を返す。window と screen(可視領域)はどちらも AX 座標。
func targetFrame(_ action: WindowAction, window: CGRect, screen: CGRect) -> CGRect {
  // ponytail: 刻みは画面の 1/24 に固定。刻みを選びたくなったら引数に出す。
  let stepX = screen.width / 24
  let stepY = screen.height / 24
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
  case .maximize:
    return screen
  case .center:
    let w = min(window.width, screen.width)
    let h = min(window.height, screen.height)
    return CGRect(x: screen.midX - w / 2, y: screen.midY - h / 2, width: w, height: h)
  case .widen: return resized(window, dw: stepX, dh: 0, screen: screen)
  case .narrow: return resized(window, dw: -stepX, dh: 0, screen: screen)
  case .taller: return resized(window, dw: 0, dh: stepY, screen: screen)
  case .shorter: return resized(window, dw: 0, dh: -stepY, screen: screen)
  case .moveLeft: return moved(window, dx: -stepX, dy: 0, screen: screen)
  case .moveRight: return moved(window, dx: stepX, dy: 0, screen: screen)
  case .moveUp: return moved(window, dx: 0, dy: -stepY, screen: screen)
  case .moveDown: return moved(window, dx: 0, dy: stepY, screen: screen)
  }
}

/// 中心を保って幅を dw、高さを dh だけ伸縮し、最小 2 刻みに揃えてから screen の中へ押し戻す。
private func resized(_ window: CGRect, dw: CGFloat, dh: CGFloat, screen: CGRect) -> CGRect {
  let w = min(max(window.width + dw, 2 * screen.width / 24), screen.width)
  let h = min(max(window.height + dh, 2 * screen.height / 24), screen.height)
  return CGRect(
    x: clamp(window.midX - w / 2, screen.minX, screen.maxX - w),
    y: clamp(window.midY - h / 2, screen.minY, screen.maxY - h), width: w, height: h)
}

/// dx・dy だけ動かし、screen の端で止める。
private func moved(_ window: CGRect, dx: CGFloat, dy: CGFloat, screen: CGRect) -> CGRect {
  CGRect(
    x: clamp(window.minX + dx, screen.minX, screen.maxX - window.width),
    y: clamp(window.minY + dy, screen.minY, screen.maxY - window.height),
    width: window.width, height: window.height)
}

/// v を lo...hi に収める。hi < lo(窓が画面より大きい)のときは lo を優先し、左上の端を画面内に残す。
private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
  max(lo, min(v, hi))
}
