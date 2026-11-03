import AppKit

/// 範囲を撮って浮かべた画像の一覧。閉じた画像は一覧から外す。
@MainActor final class FloatingScreenshots {
  private var windows: [FloatingWindow] = []
  private var isCapturing = false

  /// 範囲を選ばせて撮り、撮った画像を浮かべる。画面収録が許可されていなければ許可を求める。
  func capture() {
    // shortcut: 撮影中と許可のアラートの表示中の再押下は無視, screencapture が戻らない事象を観測したら再押下で前の撮影を終了させる
    guard !isCapturing else {
      NSLog("%@", "LaunchpadLite: 撮影中なので無視した")
      return
    }
    isCapturing = true
    guard CGPreflightScreenCaptureAccess() else {
      NSLog("%@", "LaunchpadLite: 画面収録が許可されていない")
      askForScreenCaptureAccess()
      isCapturing = false
      return
    }
    Task { @MainActor in
      defer { isCapturing = false }
      do {
        guard let capture = try await captureInteractively() else { return }
        show(capture)
      } catch {
        NSLog("%@", "LaunchpadLite: スクリーンショットを撮れなかった \(describe(error))")
        showFailureAlert(title: "スクリーンショットを撮れませんでした", message: "もう一度お試しください。")
      }
    }
  }

  /// 一覧から外す。
  func remove(_ window: FloatingWindow) {
    windows.removeAll { $0 === window }
    returnFocusIfIdle()
  }

  /// 浮かべた画像が無く、設定ウィンドウも出ていなければ、前面を直前のアプリへ返す。
  private func returnFocusIfIdle() {
    if windows.isEmpty, settingsWindow?.isVisible != true { NSApp.hide(nil) }
  }

  private func show(_ capture: Capture) {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.screens[0]
    let frame = floatingFrame(
      selection: capture.selection,
      imagePixelSize: CGSize(width: capture.image.width, height: capture.image.height),
      primaryScreenHeight: primaryScreenHeight(), mouseLocation: mouse,
      backingScaleFactor: screen.backingScaleFactor)
    let window = FloatingWindow(
      image: capture.image, frame: frame, spaceMode: currentScreenshotSettings.spaceMode,
      onClose: { [weak self] in self?.remove($0) })
    windows.append(window)
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
    let placement = capture.selection == nil ? "cursor" : "selection"
    NSLog(
      "%@",
      "LaunchpadLite: スクリーンショットを浮かべた placement=\(placement) width=\(Int(frame.width)) height=\(Int(frame.height))"
    )
  }

  private func askForScreenCaptureAccess() {
    NSApp.activate()
    let alert = NSAlert()
    alert.messageText = "画面収録の許可が必要です"
    alert.informativeText =
      "システム設定の「プライバシーとセキュリティ」にある画面収録の項目で LaunchpadLite を許可してから、LaunchpadLite を開き直してください。"
    alert.addButton(withTitle: "システム設定を開く")
    alert.addButton(withTitle: "キャンセル")
    guard alert.runModal() == .alertFirstButtonReturn else {
      returnFocusIfIdle()
      return
    }
    // 一度要求すると、システム設定の画面収録の一覧に LaunchpadLite が載る。
    _ = CGRequestScreenCaptureAccess()
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    {
      NSWorkspace.shared.open(url)
    }
  }
}

/// 撮影の失敗をログの属性にする。
private func describe(_ error: any Error) -> String {
  switch error as? CaptureError {
  case .launchFailed: "error.type=launchFailed"
  case .exitStatus(let status): "error.type=exitStatus status=\(status)"
  case .unreadableImage: "error.type=unreadableImage"
  case .none: "error.type=\(type(of: error))"
  }
}

/// 失敗を知らせるアラートを前面に出し、閉じるまで待つ。
@MainActor func showFailureAlert(title: String, message: String) {
  NSApp.activate()
  let alert = NSAlert()
  alert.messageText = title
  alert.informativeText = message
  alert.addButton(withTitle: "OK")
  alert.runModal()
}
