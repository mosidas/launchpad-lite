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
  (kVK_ANSI_C, ctrlOpt, .centerThreeQuarters),
]
for (keyCode, modifiers, action) in windowHotKeys {
  registerHotKey(keyCode: UInt32(keyCode), modifiers: modifiers) { apply(action) }
}

let systemHotKeys: [(Int, UInt32, @MainActor () -> Void)] = [
  (kVK_ANSI_S, ctrlOpt, captureRegionToClipboard),
  (kVK_ANSI_L, ctrlOpt, lockScreen),
  (kVK_ANSI_L, ctrlOpt | UInt32(shiftKey), sleepNow),
]
for (keyCode, modifiers, action) in systemHotKeys {
  registerHotKey(keyCode: UInt32(keyCode), modifiers: modifiers, action: action)
}

app.run()
