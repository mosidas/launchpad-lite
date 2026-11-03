import AppKit
import UniformTypeIdentifiers

/// 浮かべた画像に対する操作。キー操作と右クリックのメニューの両方から使う。
enum FloatingCommand: CaseIterable {
  case copy, save, zoomIn, zoomOut, resetFrame, showOnAllSpaces, showOnCurrentSpace, close

  var title: String {
    switch self {
    case .copy: "コピー"
    case .save: "保存…"
    case .zoomIn: "拡大"
    case .zoomOut: "縮小"
    case .resetFrame: "元の位置と大きさに戻す"
    case .showOnAllSpaces: "すべての Space に表示"
    case .showOnCurrentSpace: "現在の Space だけに表示"
    case .close: "閉じる"
    }
  }

  /// ⌘ と組み合わせるキー。空ならキー操作は無い。
  var keyEquivalent: String {
    switch self {
    case .copy: "c"
    case .save: "s"
    case .zoomIn: "+"
    case .zoomOut: "-"
    case .resetFrame: "0"
    case .showOnAllSpaces, .showOnCurrentSpace: ""
    case .close: "w"
    }
  }

  /// 押したキー(修飾を除いた文字)と修飾キーに当たる操作。⌘ が要る。Escape だけは修飾なしで閉じる。
  init?(characters: String, modifiers: NSEvent.ModifierFlags) {
    let flags = modifiers.intersection([.command, .option, .control, .shift])
    if characters == "\u{1b}" {
      guard flags.isEmpty else { return nil }
      self = .close
      return
    }
    // US 配列の + は ⇧= で、JIS 配列の + は ⇧; にある。⇧ を押さなくても拡大できるようにする。
    let character = characters == "=" || characters == ";" ? "+" : characters
    guard flags.subtracting(.shift) == .command, !character.isEmpty,
      let command = Self.allCases.first(where: { $0.keyEquivalent == character })
    else { return nil }
    self = command
  }
}

extension SpaceMode {
  var collectionBehavior: NSWindow.CollectionBehavior {
    switch self {
    case .allSpaces: [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    case .currentSpace: [.stationary, .fullScreenAuxiliary]
    }
  }
}

/// 拡縮の段階を step だけ動かす。段階は -3...6(25%〜250%)に収める。
func clampedZoomLevel(_ level: Int, step: Int) -> Int {
  min(max(level + step, -3), 6)
}

/// ホイールの縦の量で不透明度を変える。0.1...1 に収める。
func scrolledOpacity(_ opacity: CGFloat, deltaY: CGFloat) -> CGFloat {
  min(max(opacity + deltaY * 0.005, 0.1), 1)
}

/// original を段階 level の倍率(1 + 0.25 × level)で、中心を保って拡縮した矩形。
func frame(_ original: CGRect, scaledTo level: Int) -> CGRect {
  let scale = 1 + 0.25 * CGFloat(level)
  let width = original.width * scale
  let height = original.height * scale
  return CGRect(
    x: original.midX - width / 2, y: original.midY - height / 2, width: width, height: height)
}

/// 撮った画像を最前面に浮かべる枠なしのウィンドウ。
final class FloatingWindow: NSWindow {
  private let image: CGImage
  /// 浮かべたときの矩形。拡縮の基準の大きさと、「元の位置と大きさに戻す」の戻り先。
  private let originalFrame: CGRect
  private var zoomLevel = 0
  private var opacity: CGFloat = 1
  private var spaceMode: SpaceMode
  private let onClose: @MainActor (FloatingWindow) -> Void

  init(
    image: CGImage, frame: CGRect, spaceMode: SpaceMode,
    onClose: @escaping @MainActor (FloatingWindow) -> Void
  ) {
    self.image = image
    originalFrame = frame
    self.spaceMode = spaceMode
    self.onClose = onClose
    super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    level = .floating
    isMovableByWindowBackground = true
    hasShadow = true
    isReleasedWhenClosed = false
    // ウィンドウ単位で撮った画像は角が透明なので、背景を透かす。
    isOpaque = false
    backgroundColor = .clear
    // ランチャーを閉じたときなどに自アプリが隠れても、浮かべたままにする。
    canHide = false
    collectionBehavior = spaceMode.collectionBehavior
    setAccessibilityLabel("スクリーンショット")
    contentView?.wantsLayer = true
    contentView?.layer?.contents = image
    contentView?.layer?.contentsGravity = .resize
    contentView?.menu = makeMenu()
    // 背景のドラッグで動かした後に mouseUp が届かない場合に備え、移動の終わりでも不透明度を戻す。
    NotificationCenter.default.addObserver(
      self, selector: #selector(restoreOpacity), name: NSWindow.didMoveNotification, object: self)
  }

  override var canBecomeKey: Bool { true }

  override func keyDown(with event: NSEvent) {
    if let characters = event.charactersIgnoringModifiers,
      let command = FloatingCommand(characters: characters, modifiers: event.modifierFlags)
    {
      perform(command)
    } else {
      super.keyDown(with: event)
    }
  }

  override func scrollWheel(with event: NSEvent) {
    opacity = scrolledOpacity(opacity, deltaY: event.deltaY)
    alphaValue = opacity
  }

  override func mouseDown(with event: NSEvent) {
    alphaValue = min(opacity, currentScreenshotSettings.movingOpacity)
    super.mouseDown(with: event)
  }

  override func mouseUp(with event: NSEvent) {
    alphaValue = opacity
    if event.clickCount >= 2 { close() }
  }

  /// ⌘W・Escape・ダブルクリック・メニューの、すべての閉じる経路が通る。
  override func close() {
    super.close()
    onClose(self)
  }

  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    switch menuItem.representedObject as? FloatingCommand {
    case .showOnAllSpaces: menuItem.state = spaceMode == .allSpaces ? .on : .off
    case .showOnCurrentSpace: menuItem.state = spaceMode == .currentSpace ? .on : .off
    case .none: return super.validateMenuItem(menuItem)
    default: break
    }
    return true
  }

  private func makeMenu() -> NSMenu {
    let groups: [[FloatingCommand]] = [
      [.copy, .save], [.zoomIn, .zoomOut, .resetFrame], [.showOnAllSpaces, .showOnCurrentSpace],
      [.close],
    ]
    let menu = NSMenu()
    for (index, group) in groups.enumerated() {
      if index > 0 { menu.addItem(.separator()) }
      for command in group {
        let item = NSMenuItem(
          title: command.title, action: #selector(performMenuItem(_:)),
          keyEquivalent: command.keyEquivalent)
        item.target = self
        item.representedObject = command
        menu.addItem(item)
      }
    }
    return menu
  }

  @objc private func performMenuItem(_ sender: NSMenuItem) {
    if let command = sender.representedObject as? FloatingCommand { perform(command) }
  }

  @objc private func restoreOpacity() {
    alphaValue = opacity
  }

  private func perform(_ command: FloatingCommand) {
    switch command {
    case .copy: copyImage()
    case .save: saveImage()
    case .zoomIn: zoom(to: clampedZoomLevel(zoomLevel, step: 1))
    case .zoomOut: zoom(to: clampedZoomLevel(zoomLevel, step: -1))
    case .resetFrame:
      zoomLevel = 0
      setFrame(originalFrame, display: true, animate: true)
    case .showOnAllSpaces: setSpaceMode(.allSpaces)
    case .showOnCurrentSpace: setSpaceMode(.currentSpace)
    case .close: close()
    }
  }

  /// 今の中心を保ったまま、元の大きさを段階 level に拡縮する。動かした後の位置からは動かさない。
  private func zoom(to level: Int) {
    zoomLevel = level
    let base = CGRect(
      x: frame.midX - originalFrame.width / 2, y: frame.midY - originalFrame.height / 2,
      width: originalFrame.width, height: originalFrame.height)
    setFrame(LaunchpadLite.frame(base, scaledTo: level), display: true, animate: true)
  }

  private func setSpaceMode(_ mode: SpaceMode) {
    spaceMode = mode
    collectionBehavior = mode.collectionBehavior
  }

  private func copyImage() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    // 大きさは浮かべたときのポイント寸法にする。拡縮中の大きさを渡すと、貼った先で解像度がずれる。
    if !pasteboard.writeObjects([NSImage(cgImage: image, size: originalFrame.size)]) {
      NSLog("%@", "LaunchpadLite: 画像をクリップボードへ書けなかった")
      showFailureAlert(title: "画像をコピーできませんでした", message: "もう一度お試しください。")
    }
  }

  /// 保存先を選ばせて PNG で書く。取り消したら何もしない。失敗してもウィンドウは残す。
  private func saveImage() {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "スクリーンショット \(formatter.string(from: .now)).png"
    panel.level = .modalPanel
    NSApp.activate()
    guard panel.runModal() == .OK, let url = panel.url else { return }
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
      reportSaveFailure()
      return
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) { reportSaveFailure() }
  }

  private func reportSaveFailure() {
    NSLog("%@", "LaunchpadLite: 画像を保存できなかった")
    showFailureAlert(
      title: "画像を保存できませんでした", message: "保存先に書き込めるかを確かめて、もう一度お試しください。")
  }
}
