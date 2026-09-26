import AppKit

/// 前面アプリのフォーカス中のウィンドウに action を適用する。AX で読み書きできなければ何もしない。
@MainActor
func apply(_ action: WindowAction) {
  guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
    let primaryHeight = NSScreen.screens.first?.frame.height
  else { return }
  var focused: CFTypeRef?
  guard
    AXUIElementCopyAttributeValue(
      AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &focused)
      == .success,
    let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
  else { return }
  let window = unsafeDowncast(focused, to: AXUIElement.self)
  var position = CGPoint.zero
  var size = CGSize.zero
  guard let positionValue = axValue(window, kAXPositionAttribute),
    AXValueGetValue(positionValue, .cgPoint, &position),
    let sizeValue = axValue(window, kAXSizeAttribute),
    AXValueGetValue(sizeValue, .cgSize, &size)
  else { return }
  let frame = CGRect(origin: position, size: size)

  func overlap(_ screen: NSScreen) -> CGFloat {
    let rect = axFrame(fromCocoa: screen.frame, primaryScreenHeight: primaryHeight)
      .intersection(frame)
    return rect.isNull ? 0 : rect.width * rect.height
  }
  guard let screen = NSScreen.screens.max(by: { overlap($0) < overlap($1) }) else { return }
  let target = targetFrame(
    action, window: frame,
    screen: axFrame(fromCocoa: screen.visibleFrame, primaryScreenHeight: primaryHeight))

  // サイズ・位置・サイズの順に書く。先に位置だけ動かすと、元の大きさのまま移動先の画面からはみ出て
  // OS に位置が補正され、先にサイズだけ変えると元の画面の大きさで頭打ちになることがある。
  // 最後にもう一度サイズを書いて、移動後の画面で狙った大きさに揃える。
  var targetSize = target.size
  var targetOrigin = target.origin
  guard let sizeValue = AXValueCreate(.cgSize, &targetSize),
    let originValue = AXValueCreate(.cgPoint, &targetOrigin)
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
