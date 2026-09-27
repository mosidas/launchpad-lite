import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// ウィンドウ操作に要るアクセシビリティ権限が無ければ、許可を求めるダイアログを出す。
// キーは kAXTrustedCheckOptionPrompt の値。定数は C のグローバル変数で Swift 6 では参照できないため文字列で書く。
_ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

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

app.run()
