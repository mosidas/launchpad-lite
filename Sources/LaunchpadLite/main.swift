import AppKit
import Carbon.HIToolbox

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// ウィンドウ操作に要るアクセシビリティ権限が無ければ、許可を求めるダイアログを出す。
// キーは kAXTrustedCheckOptionPrompt の値。定数は C のグローバル変数で Swift 6 では参照できないため文字列で書く。
_ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

let launcher = LauncherPanel()
registerHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)) { launcher.toggle() }

let cmdShift = UInt32(cmdKey | shiftKey)
let windowHotKeys: [(Int, WindowAction)] = [
  (kVK_LeftArrow, .leftHalf),
  (kVK_RightArrow, .rightHalf),
  (kVK_UpArrow, .topHalf),
  (kVK_DownArrow, .bottomHalf),
  (kVK_ANSI_1, .topRight),
  (kVK_ANSI_2, .topLeft),
  (kVK_ANSI_3, .bottomLeft),
  (kVK_ANSI_4, .bottomRight),
  (kVK_Return, .maximize),
  (kVK_ANSI_C, .centerThreeQuarters),
]
for (keyCode, action) in windowHotKeys {
  registerHotKey(keyCode: UInt32(keyCode), modifiers: cmdShift) { apply(action) }
}

let otherHotKeys: [(Int, UInt32, @MainActor () -> Void)] = [
  (kVK_LeftArrow, UInt32(controlKey | cmdKey), { moveToDisplay(.previous) }),
  (kVK_RightArrow, UInt32(controlKey | cmdKey), { moveToDisplay(.next) }),
  (kVK_ANSI_S, cmdShift, openScreenshotToolbar),
  (kVK_ANSI_S, UInt32(cmdKey | optionKey), sleepNow),
]
for (keyCode, modifiers, action) in otherHotKeys {
  registerHotKey(keyCode: UInt32(keyCode), modifiers: modifiers, action: action)
}

app.run()
