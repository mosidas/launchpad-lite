import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// ウィンドウ操作に要るアクセシビリティ権限が無ければ、許可を求めるダイアログを出す。
// キーは kAXTrustedCheckOptionPrompt の値。定数は C のグローバル変数で Swift 6 では参照できないため文字列で書く。
_ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

// トップレベルで保持する。解放されるとメニューバーのアイコンが消える。
let menuBar = MenuBar()
let launcher = LauncherPanel()
performHotKey = { action in
  switch action {
  case .launcher: launcher.toggle()
  case .screenshot: openScreenshotToolbar()
  case .leftHalf: apply(.leftHalf)
  case .rightHalf: apply(.rightHalf)
  case .topHalf: apply(.topHalf)
  case .bottomHalf: apply(.bottomHalf)
  case .topRight: apply(.topRight)
  case .topLeft: apply(.topLeft)
  case .bottomLeft: apply(.bottomLeft)
  case .bottomRight: apply(.bottomRight)
  case .maximize: apply(.maximize)
  case .centerThreeQuarters: apply(.centerThreeQuarters)
  case .previousDisplay: moveToDisplay(.previous)
  case .nextDisplay: moveToDisplay(.next)
  case .sleep: sleepNow()
  }
}
registerAllHotKeys()

applyPointerSettings(currentMouseSettings)
applyKeyRemaps(currentKeyboardSettings)
// ponytail: マウスの再接続やスリープ復帰で OS がシステム設定の値を入れ直すので、5 秒ごとに書き直す。
// キーボードの再接続・追加で置き換えが外れるのも、同じ間隔で書き直す。
// 反映まで最大 5 秒かかる。気になれば IOHIDManager の接続通知で書き直す形に引き上げる。
// ponytail: tap は未許可の間は作れず、許可を取り消すと無効になる。同じ間隔で作り直しを試み、
// 未許可・取り消しのどちらでも許可後 5 秒以内に作り直す。再起動しなくて済む。
Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
  MainActor.assumeIsolated {
    applyPointerSettings(currentMouseSettings)
    applyKeyRemaps(currentKeyboardSettings)
    restartMouseEventTapIfDisabled()
  }
}

// 終了後もキーが置き換わったままだと戻す手段が無いので、終了時に解除する。
NotificationCenter.default.addObserver(
  forName: NSApplication.willTerminateNotification, object: nil, queue: .main
) { _ in
  MainActor.assumeIsolated { setKeyRemapsEnabled(false) }
}

startMouseEventTap()

app.run()
