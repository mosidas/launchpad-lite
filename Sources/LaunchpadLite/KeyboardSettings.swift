import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// キーの置き換え。from・to は kVK_*。
struct KeyRemap: Equatable, Codable {
  var from: UInt32
  var to: UInt32
}

struct KeyboardSettings: Equatable {
  /// F の番号(1〜12)ごとの動作。
  var functionKeys: [Int: MouseAction]
  /// キーの置き換え。from は重複しない。
  var remaps: [KeyRemap] = []
}

/// 保存済みの設定を返す。保存値が無いか壊れていれば空を返し、1〜12 以外の番号は捨てる。
func loadKeyboardSettings(from defaults: UserDefaults = .standard) -> KeyboardSettings {
  let keys = defaults.data(forKey: "keyboard.functionKeys").flatMap {
    try? JSONDecoder().decode([Int: MouseAction].self, from: $0)
  }
  let remaps = defaults.data(forKey: "keyboard.remaps").flatMap {
    try? JSONDecoder().decode([KeyRemap].self, from: $0)
  }
  return KeyboardSettings(
    functionKeys: (keys ?? [:]).filter { (1...12).contains($0.key) }, remaps: remaps ?? [])
}

/// 設定を保存する。nil なら保存値を消し、既定値に戻す。
func saveKeyboardSettings(_ settings: KeyboardSettings?, to defaults: UserDefaults = .standard) {
  guard let settings else {
    defaults.removeObject(forKey: "keyboard.functionKeys")
    defaults.removeObject(forKey: "keyboard.remaps")
    return
  }
  defaults.set(try? JSONEncoder().encode(settings.functionKeys), forKey: "keyboard.functionKeys")
  defaults.set(try? JSONEncoder().encode(settings.remaps), forKey: "keyboard.remaps")
}

/// 実行時の現在の設定。
@MainActor var currentKeyboardSettings = loadKeyboardSettings()

/// F キーのキーコードを F の番号(1〜12)にする。F キーでなければ nil。
func functionKeyNumber(keyCode: Int) -> Int? {
  functionKeyCodes.firstIndex(of: keyCode).map { $0 + 1 }
}

/// F キーの押下に割り当てた動作。⌘⌃⌥⇧ のどれかが付いていれば、元のキーを届けるため nil を返す。
func functionKeyAction(
  _ settings: KeyboardSettings, keyCode: Int, flags: CGEventFlags
) -> MouseAction? {
  guard flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate, .maskShift]),
    let number = functionKeyNumber(keyCode: keyCode)
  else { return nil }
  return settings.functionKeys[number]
}

/// kVK_* から HID usage(Keyboard/Keypad ページ 0x07)への表。どちらも物理位置を表すので 1 対 1 に対応する。
let hidUsages: [Int: UInt64] = {
  var usages: [Int: UInt64] = [
    kVK_ANSI_A: 0x04, kVK_ANSI_B: 0x05, kVK_ANSI_C: 0x06, kVK_ANSI_D: 0x07, kVK_ANSI_E: 0x08,
    kVK_ANSI_F: 0x09, kVK_ANSI_G: 0x0A, kVK_ANSI_H: 0x0B, kVK_ANSI_I: 0x0C, kVK_ANSI_J: 0x0D,
    kVK_ANSI_K: 0x0E, kVK_ANSI_L: 0x0F, kVK_ANSI_M: 0x10, kVK_ANSI_N: 0x11, kVK_ANSI_O: 0x12,
    kVK_ANSI_P: 0x13, kVK_ANSI_Q: 0x14, kVK_ANSI_R: 0x15, kVK_ANSI_S: 0x16, kVK_ANSI_T: 0x17,
    kVK_ANSI_U: 0x18, kVK_ANSI_V: 0x19, kVK_ANSI_W: 0x1A, kVK_ANSI_X: 0x1B, kVK_ANSI_Y: 0x1C,
    kVK_ANSI_Z: 0x1D,
    kVK_ANSI_1: 0x1E, kVK_ANSI_2: 0x1F, kVK_ANSI_3: 0x20, kVK_ANSI_4: 0x21, kVK_ANSI_5: 0x22,
    kVK_ANSI_6: 0x23, kVK_ANSI_7: 0x24, kVK_ANSI_8: 0x25, kVK_ANSI_9: 0x26, kVK_ANSI_0: 0x27,
    kVK_Return: 0x28, kVK_Escape: 0x29, kVK_Delete: 0x2A, kVK_Tab: 0x2B, kVK_Space: 0x2C,
    kVK_ANSI_Minus: 0x2D, kVK_ANSI_Equal: 0x2E, kVK_ANSI_LeftBracket: 0x2F,
    kVK_ANSI_RightBracket: 0x30, kVK_ANSI_Backslash: 0x31, kVK_ANSI_Semicolon: 0x33,
    kVK_ANSI_Quote: 0x34, kVK_ANSI_Grave: 0x35, kVK_ANSI_Comma: 0x36, kVK_ANSI_Period: 0x37,
    kVK_ANSI_Slash: 0x38, kVK_CapsLock: 0x39,
    kVK_F13: 0x68, kVK_F14: 0x69, kVK_F15: 0x6A, kVK_F16: 0x6B, kVK_F17: 0x6C, kVK_F18: 0x6D,
    kVK_F19: 0x6E, kVK_F20: 0x6F,
    kVK_Help: 0x49, kVK_Home: 0x4A, kVK_PageUp: 0x4B, kVK_ForwardDelete: 0x4C, kVK_End: 0x4D,
    kVK_PageDown: 0x4E, kVK_RightArrow: 0x4F, kVK_LeftArrow: 0x50, kVK_DownArrow: 0x51,
    kVK_UpArrow: 0x52,
    kVK_ANSI_KeypadClear: 0x53, kVK_ANSI_KeypadEquals: 0x67, kVK_ANSI_KeypadDivide: 0x54,
    kVK_ANSI_KeypadMultiply: 0x55, kVK_ANSI_KeypadMinus: 0x56, kVK_ANSI_KeypadPlus: 0x57,
    kVK_ANSI_KeypadEnter: 0x58, kVK_ANSI_Keypad1: 0x59, kVK_ANSI_Keypad2: 0x5A,
    kVK_ANSI_Keypad3: 0x5B, kVK_ANSI_Keypad4: 0x5C, kVK_ANSI_Keypad5: 0x5D,
    kVK_ANSI_Keypad6: 0x5E, kVK_ANSI_Keypad7: 0x5F, kVK_ANSI_Keypad8: 0x60,
    kVK_ANSI_Keypad9: 0x61, kVK_ANSI_Keypad0: 0x62, kVK_ANSI_KeypadDecimal: 0x63,
    kVK_ISO_Section: 0x64,
    kVK_JIS_Yen: 0x89, kVK_JIS_Underscore: 0x87, kVK_JIS_KeypadComma: 0x85, kVK_JIS_Kana: 0x90,
    kVK_JIS_Eisu: 0x91,
    kVK_Control: 0xE0, kVK_Shift: 0xE1, kVK_Option: 0xE2, kVK_Command: 0xE3,
    kVK_RightControl: 0xE4, kVK_RightShift: 0xE5, kVK_RightOption: 0xE6, kVK_RightCommand: 0xE7,
  ]
  for (i, code) in functionKeyCodes.enumerated() { usages[code] = 0x3A + UInt64(i) }
  return usages
}()

/// kVK_* の HID usage。表に無いキーなら nil。
func hidUsage(keyCode: UInt32) -> UInt64? {
  hidUsages[Int(keyCode)]
}

/// IOHIDEventSystem の UserKeyMapping に書く値(hidutil と同じ形)。表に無いキーを含む組は捨てる。
func userKeyMapping(_ remaps: [KeyRemap]) -> [[String: UInt64]] {
  remaps.compactMap { remap in
    guard let src = hidUsage(keyCode: remap.from), let dst = hidUsage(keyCode: remap.to) else {
      return nil
    }
    return [
      "HIDKeyboardModifierMappingSrc": 0x7_0000_0000 | src,
      "HIDKeyboardModifierMappingDst": 0x7_0000_0000 | dst,
    ]
  }
}
