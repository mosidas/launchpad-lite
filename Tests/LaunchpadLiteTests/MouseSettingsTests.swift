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

private let defaultBindings = [
  MouseBinding(trigger: .button(3), action: .system(.back)),
  MouseBinding(trigger: .button(4), action: .system(.forward)),
]

@Test func defaultBindingsMapSideButtonsToBackForward() {
  withDefaults { defaults in
    let settings = loadMouseSettings(from: defaults)
    #expect(settings.bindings == defaultBindings)
    #expect(settings.action(for: .button(3)) == .system(.back))
    #expect(settings.action(for: .button(4)) == .system(.forward))
    #expect(settings.action(for: .button(2)) == nil)
    #expect(!settings.reverseVertical)
    #expect(settings.reverseHorizontal)
    #expect(settings.scrollLines == 4)
  }
}

@Test func pointerDefaultsFollowSystemSettings() {
  withDefaults { defaults in
    defaults.set(true, forKey: "com.apple.mouse.linear")
    defaults.set(2.0, forKey: "com.apple.mouse.scaling")
    let settings = loadMouseSettings(from: defaults)
    #expect(!settings.pointerAcceleration)
    #expect(settings.pointerSpeed == 2.0)
  }
}

@Test func saveThenLoadRoundTripsMouseSettings() {
  withDefaults { defaults in
    let combo = KeyCombo(keyCode: UInt32(kVK_UpArrow), modifiers: UInt32(controlKey))
    var settings = MouseSettings(
      pointerAcceleration: false, pointerSpeed: 1.1, reverseVertical: true,
      reverseHorizontal: false, scrollLines: 7,
      bindings: [
        MouseBinding(trigger: .button(5), action: .shortcut(combo)),
        MouseBinding(trigger: .thumbLeft, action: .system(.volumeDown)),
        MouseBinding(trigger: .thumbRight, action: .system(.volumeUp)),
      ])
    saveMouseSettings(settings, to: defaults)
    #expect(loadMouseSettings(from: defaults) == settings)
    settings.bindings = []
    saveMouseSettings(settings, to: defaults)
    #expect(loadMouseSettings(from: defaults) == settings)
  }
}

@Test func invalidValuesFallBackOrClamp() {
  withDefaults { defaults in
    defaults.set(true, forKey: "com.apple.mouse.linear")
    defaults.set("x", forKey: "mouse.pointerAcceleration")
    defaults.set("x", forKey: "mouse.reverseVertical")
    defaults.set(Data("broken".utf8), forKey: "mouse.bindings")
    defaults.set(9.0, forKey: "mouse.pointerSpeed")
    defaults.set(0, forKey: "mouse.scrollLines")
    var settings = loadMouseSettings(from: defaults)
    #expect(!settings.pointerAcceleration)
    #expect(!settings.reverseVertical)
    #expect(settings.bindings == defaultBindings)
    #expect(settings.pointerSpeed == 3)
    #expect(settings.scrollLines == 1)
    defaults.set(-1.0, forKey: "mouse.pointerSpeed")
    defaults.set(99, forKey: "mouse.scrollLines")
    defaults.set("x", forKey: "mouse.bindings")
    settings = loadMouseSettings(from: defaults)
    #expect(settings.pointerSpeed == 0)
    #expect(settings.scrollLines == 20)
    #expect(settings.bindings == defaultBindings)
  }
}

@Test func savingNilRemovesMouseKeys() {
  withDefaults { defaults in
    var settings = loadMouseSettings(from: defaults)
    settings.scrollLines = 9
    saveMouseSettings(settings, to: defaults)
    saveMouseSettings(nil, to: defaults)
    for key in [
      "pointerAcceleration", "pointerSpeed", "reverseVertical", "reverseHorizontal",
      "scrollLines", "bindings",
    ] {
      #expect(defaults.object(forKey: "mouse.\(key)") == nil)
    }
    #expect(loadMouseSettings(from: defaults).scrollLines == 4)
  }
}

@Test func triggerAndActionTitles() {
  #expect(MouseTrigger.button(3).title == "ボタン 4")
  #expect(MouseTrigger.thumbLeft.title == "サムホイール左")
  #expect(SystemAction.allCases.count == 12)
  #expect(Set(SystemAction.allCases.map(\.title)).count == 12)
}
