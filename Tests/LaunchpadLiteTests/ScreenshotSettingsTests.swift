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

@Test func screenshotSettingsDefaultToTranslucentOnAllSpaces() {
  withDefaults { defaults in
    let settings = loadScreenshotSettings(from: defaults)
    #expect(settings.movingOpacity == 0.7)
    #expect(settings.spaceMode == .allSpaces)
  }
}

@Test func saveThenLoadRoundTripsScreenshotSettings() {
  withDefaults { defaults in
    let settings = ScreenshotSettings(movingOpacity: 0.45, spaceMode: .currentSpace)
    saveScreenshotSettings(settings, to: defaults)
    #expect(loadScreenshotSettings(from: defaults) == settings)
  }
}

@Test func loadReadsScreenshotKeys() {
  withDefaults { defaults in
    defaults.set(0.3, forKey: "screenshot.movingOpacity")
    defaults.set("currentSpace", forKey: "screenshot.spaceMode")
    let settings = loadScreenshotSettings(from: defaults)
    #expect(settings.movingOpacity == 0.3)
    #expect(settings.spaceMode == .currentSpace)
  }
}

@Test func invalidScreenshotValuesFallBackOrClamp() {
  withDefaults { defaults in
    defaults.set(Double.nan, forKey: "screenshot.movingOpacity")
    defaults.set("bogus", forKey: "screenshot.spaceMode")
    var settings = loadScreenshotSettings(from: defaults)
    #expect(settings.movingOpacity == 0.7, "NaN は既定値")
    #expect(settings.spaceMode == .allSpaces, "未知の文字列は既定値")
    defaults.set("abc", forKey: "screenshot.movingOpacity")
    defaults.set(1, forKey: "screenshot.spaceMode")
    settings = loadScreenshotSettings(from: defaults)
    #expect(settings.movingOpacity == 0.7, "文字列は既定値")
    #expect(settings.spaceMode == .allSpaces, "整数は既定値")
    defaults.set(5.0, forKey: "screenshot.movingOpacity")
    #expect(loadScreenshotSettings(from: defaults).movingOpacity == 1.0)
    defaults.set(0.0, forKey: "screenshot.movingOpacity")
    #expect(loadScreenshotSettings(from: defaults).movingOpacity == 0.1)
  }
}

@Test func savingNilRemovesScreenshotKeys() {
  withDefaults { defaults in
    saveScreenshotSettings(
      ScreenshotSettings(movingOpacity: 0.4, spaceMode: .currentSpace), to: defaults)
    saveScreenshotSettings(nil, to: defaults)
    #expect(defaults.object(forKey: "screenshot.movingOpacity") == nil)
    #expect(defaults.object(forKey: "screenshot.spaceMode") == nil)
    #expect(
      loadScreenshotSettings(from: defaults)
        == ScreenshotSettings(movingOpacity: 0.7, spaceMode: .allSpaces))
  }
}
