import CoreGraphics
import Foundation

struct KeyboardSettings: Equatable {
  /// F の番号(1〜12)ごとの動作。
  var functionKeys: [Int: MouseAction]
}

/// 保存済みの設定を返す。保存値が無いか壊れていれば空を返し、1〜12 以外の番号は捨てる。
func loadKeyboardSettings(from defaults: UserDefaults = .standard) -> KeyboardSettings {
  let keys = defaults.data(forKey: "keyboard.functionKeys").flatMap {
    try? JSONDecoder().decode([Int: MouseAction].self, from: $0)
  }
  return KeyboardSettings(functionKeys: (keys ?? [:]).filter { (1...12).contains($0.key) })
}

/// 設定を保存する。nil なら保存値を消し、既定値に戻す。
func saveKeyboardSettings(_ settings: KeyboardSettings?, to defaults: UserDefaults = .standard) {
  guard let settings else {
    defaults.removeObject(forKey: "keyboard.functionKeys")
    return
  }
  defaults.set(try? JSONEncoder().encode(settings.functionKeys), forKey: "keyboard.functionKeys")
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
