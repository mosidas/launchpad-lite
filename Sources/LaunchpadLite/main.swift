import AppKit
import Carbon.HIToolbox

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// ウィンドウ操作に要るアクセシビリティ権限が無ければ、許可を求めるダイアログを出す。
// キーは kAXTrustedCheckOptionPrompt の値。定数は C のグローバル変数で Swift 6 では参照できないため文字列で書く。
_ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

let launcher = LauncherPanel()
registerHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)) { launcher.toggle() }

let ctrlOpt = UInt32(controlKey | optionKey)
let windowHotKeys: [(Int, UInt32, WindowAction)] = [
  (kVK_LeftArrow, ctrlOpt, .leftHalf),
  (kVK_RightArrow, ctrlOpt, .rightHalf),
  (kVK_UpArrow, ctrlOpt, .topHalf),
  (kVK_DownArrow, ctrlOpt, .bottomHalf),
  (kVK_Return, ctrlOpt, .maximize),
  (kVK_ANSI_C, ctrlOpt, .center),
  (kVK_LeftArrow, ctrlOpt | UInt32(shiftKey), .narrow),
  (kVK_RightArrow, ctrlOpt | UInt32(shiftKey), .widen),
  (kVK_UpArrow, ctrlOpt | UInt32(shiftKey), .shorter),
  (kVK_DownArrow, ctrlOpt | UInt32(shiftKey), .taller),
  (kVK_LeftArrow, ctrlOpt | UInt32(cmdKey), .moveLeft),
  (kVK_RightArrow, ctrlOpt | UInt32(cmdKey), .moveRight),
  (kVK_UpArrow, ctrlOpt | UInt32(cmdKey), .moveUp),
  (kVK_DownArrow, ctrlOpt | UInt32(cmdKey), .moveDown),
]
for (keyCode, modifiers, action) in windowHotKeys {
  registerHotKey(keyCode: UInt32(keyCode), modifiers: modifiers) { apply(action) }
}

app.run()
