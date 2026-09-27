import AppKit
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

@Test func defaultCombosAreDistinct() {
  let combos = HotKeyAction.allCases.map { [$0.defaultCombo.keyCode, $0.defaultCombo.modifiers] }
  #expect(HotKeyAction.allCases.count == 15)
  #expect(Set(combos).count == combos.count)
}

@Test func defaultsMatchPreviousHardcodedKeys() {
  #expect(
    HotKeyAction.launcher.defaultCombo
      == KeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)))
  #expect(
    HotKeyAction.sleep.defaultCombo
      == KeyCombo(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | optionKey)))
}

@Test func loadFallsBackToDefault() {
  withDefaults { defaults in
    #expect(loadKeyCombo(.launcher, from: defaults) == HotKeyAction.launcher.defaultCombo)
    defaults.set([1, 2, 3], forKey: "hotKey.launcher")
    #expect(loadKeyCombo(.launcher, from: defaults) == HotKeyAction.launcher.defaultCombo)
    defaults.set(["a", "b"], forKey: "hotKey.launcher")
    #expect(loadKeyCombo(.launcher, from: defaults) == HotKeyAction.launcher.defaultCombo)
    defaults.set([-1, 0], forKey: "hotKey.launcher")
    #expect(loadKeyCombo(.launcher, from: defaults) == HotKeyAction.launcher.defaultCombo)
    defaults.set("x", forKey: "hotKey.launcher")
    #expect(loadKeyCombo(.launcher, from: defaults) == HotKeyAction.launcher.defaultCombo)
  }
}

@Test func saveThenLoadRoundTrips() {
  withDefaults { defaults in
    let combo = KeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | cmdKey))
    saveKeyCombo(combo, for: .launcher, to: defaults)
    #expect(loadKeyCombo(.launcher, from: defaults) == combo)
    #expect(loadKeyCombo(.sleep, from: defaults) == HotKeyAction.sleep.defaultCombo)
  }
}

@Test func savingNilRestoresDefault() {
  withDefaults { defaults in
    saveKeyCombo(KeyCombo(keyCode: 1, modifiers: 2), for: .maximize, to: defaults)
    saveKeyCombo(nil, for: .maximize, to: defaults)
    #expect(loadKeyCombo(.maximize, from: defaults) == HotKeyAction.maximize.defaultCombo)
    #expect(defaults.object(forKey: "hotKey.maximize") == nil)
  }
}

@Test func carbonModifiersMapsEachFlag() {
  #expect(carbonModifiers(.command) == UInt32(cmdKey))
  #expect(carbonModifiers(.shift) == UInt32(shiftKey))
  #expect(carbonModifiers(.option) == UInt32(optionKey))
  #expect(carbonModifiers(.control) == UInt32(controlKey))
  #expect(carbonModifiers([.command, .shift]) == UInt32(cmdKey | shiftKey))
  #expect(carbonModifiers([.capsLock, .function, .numericPad]) == 0)
  #expect(carbonModifiers([.control, .capsLock]) == UInt32(controlKey))
}

@Test func labelOrdersModifiersAndNamesKeys() {
  #expect(HotKeyAction.launcher.defaultCombo.label == "⌘Space")
  #expect(HotKeyAction.leftHalf.defaultCombo.label == "⇧⌘←")
  #expect(HotKeyAction.previousDisplay.defaultCombo.label == "⌃⌘←")
  #expect(HotKeyAction.sleep.defaultCombo.label == "⌥⌘S")
  #expect(HotKeyAction.topRight.defaultCombo.label == "⇧⌘1")
  #expect(KeyCombo(keyCode: UInt32(kVK_F12), modifiers: UInt32(controlKey)).label == "⌃F12")
  #expect(KeyCombo(keyCode: 999, modifiers: UInt32(cmdKey)).label == "⌘Key999")
}
