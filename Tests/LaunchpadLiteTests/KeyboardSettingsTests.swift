import Carbon.HIToolbox
import Foundation
import Testing

@testable import LaunchpadLite

/// 使い捨ての UserDefaults を渡して body を実行し、終わったら消す。
private func withDefaults(_ body: (UserDefaults) -> Void) {
  let name = "launchpad-lite-test-\(UUID())"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  body(defaults)
}

@Test func keyboardDefaultsAreEmpty() {
  withDefaults { defaults in
    #expect(loadKeyboardSettings(from: defaults).functionKeys.isEmpty)
  }
}

@Test func saveThenLoadRoundTripsKeyboardSettings() {
  withDefaults { defaults in
    let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey))
    let settings = KeyboardSettings(functionKeys: [1: .system(.mute), 12: .shortcut(combo)])
    saveKeyboardSettings(settings, to: defaults)
    #expect(loadKeyboardSettings(from: defaults) == settings)
  }
}

@Test func savingNilRemovesKeyboardKey() {
  withDefaults { defaults in
    saveKeyboardSettings(KeyboardSettings(functionKeys: [3: .system(.volumeUp)]), to: defaults)
    saveKeyboardSettings(nil, to: defaults)
    #expect(defaults.object(forKey: "keyboard.functionKeys") == nil)
    #expect(loadKeyboardSettings(from: defaults).functionKeys.isEmpty)
  }
}

@Test func invalidKeyboardValuesFallBack() {
  withDefaults { defaults in
    defaults.set(Data("broken".utf8), forKey: "keyboard.functionKeys")
    #expect(loadKeyboardSettings(from: defaults).functionKeys.isEmpty)
    let keys: [Int: MouseAction] = [0: .system(.mute), 5: .system(.playPause), 13: .system(.back)]
    defaults.set(try! JSONEncoder().encode(keys), forKey: "keyboard.functionKeys")
    #expect(loadKeyboardSettings(from: defaults).functionKeys == [5: .system(.playPause)])
  }
}

@Test func functionKeyNumbers() {
  #expect(functionKeyNumber(keyCode: kVK_F1) == 1)
  #expect(functionKeyNumber(keyCode: kVK_F12) == 12)
  #expect(functionKeyNumber(keyCode: kVK_ANSI_A) == nil)
}

@Test func functionKeyActionSkipsModifiedKeys() {
  let settings = KeyboardSettings(functionKeys: [1: .system(.mute)])
  #expect(functionKeyAction(settings, keyCode: kVK_F1, flags: []) == .system(.mute))
  #expect(functionKeyAction(settings, keyCode: kVK_F2, flags: []) == nil)
  for flag: CGEventFlags in [.maskCommand, .maskControl, .maskAlternate, .maskShift] {
    #expect(functionKeyAction(settings, keyCode: kVK_F1, flags: flag) == nil)
  }
  #expect(functionKeyAction(settings, keyCode: kVK_F1, flags: .maskSecondaryFn) == .system(.mute))
}
