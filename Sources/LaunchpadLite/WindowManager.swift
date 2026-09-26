import AppKit

enum DisplayDirection { case previous, next }

/// 前面アプリのフォーカス中のウィンドウに action を適用する。AX で読み書きできなければ何もしない。
@MainActor
func apply(_ action: WindowAction) {
  guard let focused = focusedWindow() else { return }
  let screens = NSScreen.screens
  guard let i = screenIndex(of: focused.frame, in: screens) else { return }
  setFrame(focused.window, targetFrame(action, screen: axVisibleFrame(screens[i])))
}

/// フォーカス中のウィンドウを前 / 次のディスプレイへ、可視領域に対する比率を保って移す。
/// ディスプレイは左から順に並べ、端では反対側へ回る。ディスプレイが 1 つなら何もしない。
@MainActor
func moveToDisplay(_ direction: DisplayDirection) {
  let screens = NSScreen.screens.sorted {
    ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY)
  }
  guard screens.count > 1, let focused = focusedWindow(),
    let i = screenIndex(of: focused.frame, in: screens)
  else { return }
  let j = (i + (direction == .next ? 1 : -1) + screens.count) % screens.count
  setFrame(
    focused.window,
    frameMoved(
      window: focused.frame, from: axVisibleFrame(screens[i]), to: axVisibleFrame(screens[j])))
}

/// 前面アプリのフォーカス中のウィンドウと、その矩形(AX 座標)を返す。読めなければ nil。
@MainActor
private func focusedWindow() -> (window: AXUIElement, frame: CGRect)? {
  guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
  var focused: CFTypeRef?
  guard
    AXUIElementCopyAttributeValue(
      AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &focused)
      == .success,
    let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
  else { return nil }
  let window = unsafeDowncast(focused, to: AXUIElement.self)
  var position = CGPoint.zero
  var size = CGSize.zero
  guard let positionValue = axValue(window, kAXPositionAttribute),
    AXValueGetValue(positionValue, .cgPoint, &position),
    let sizeValue = axValue(window, kAXSizeAttribute),
    AXValueGetValue(sizeValue, .cgSize, &size)
  else { return nil }
  return (window, CGRect(origin: position, size: size))
}

/// screens のうち frame(AX 座標)と重なる面積が最大の画面の添字を返す。
@MainActor
private func screenIndex(of frame: CGRect, in screens: [NSScreen]) -> Int? {
  func overlap(_ i: Int) -> CGFloat {
    let rect = axFrame(fromCocoa: screens[i].frame, primaryScreenHeight: primaryScreenHeight())
      .intersection(frame)
    return rect.isNull ? 0 : rect.width * rect.height
  }
  return screens.indices.max { overlap($0) < overlap($1) }
}

/// screen の可視領域を AX 座標で返す。
@MainActor
private func axVisibleFrame(_ screen: NSScreen) -> CGRect {
  axFrame(fromCocoa: screen.visibleFrame, primaryScreenHeight: primaryScreenHeight())
}

/// 主画面(NSScreen.screens の先頭)の高さ。呼び出し元は画面を 1 つ以上持っている前提で呼ぶ。
@MainActor
private func primaryScreenHeight() -> CGFloat { NSScreen.screens[0].frame.height }

/// window の矩形を frame(AX 座標)にする。
private func setFrame(_ window: AXUIElement, _ frame: CGRect) {
  // サイズ・位置・サイズの順に書く。先に位置だけ動かすと、元の大きさのまま移動先の画面からはみ出て
  // OS に位置が補正され、先にサイズだけ変えると元の画面の大きさで頭打ちになることがある。
  // 最後にもう一度サイズを書いて、移動後の画面で狙った大きさに揃える。
  var size = frame.size
  var origin = frame.origin
  guard let sizeValue = AXValueCreate(.cgSize, &size),
    let originValue = AXValueCreate(.cgPoint, &origin)
  else { return }
  AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
  AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, originValue)
  AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
}

/// AXValue の属性(位置・サイズ)を読む。読めなければ nil。
private func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
  var ref: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
    let ref, CFGetTypeID(ref) == AXValueGetTypeID()
  else { return nil }
  return unsafeDowncast(ref, to: AXValue.self)
}
