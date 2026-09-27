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
// ponytail: マウスの再接続やスリープ復帰で OS がシステム設定の値を入れ直すので、5 秒ごとに書き直す。
// 反映まで最大 5 秒かかる。気になれば IOHIDManager の接続通知で書き直す形に引き上げる。
// ponytail: tap は未許可の間は作れないので、同じ間隔で作り直しを試みる。許可後に再起動しなくて済む。
Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
  MainActor.assumeIsolated {
    applyPointerSettings(currentMouseSettings)
    startMouseEventTap()
  }
}

startMouseEventTap()

app.run()
