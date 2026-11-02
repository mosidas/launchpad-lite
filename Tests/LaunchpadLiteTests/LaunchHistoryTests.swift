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

private let safari = URL(fileURLWithPath: "/Applications/Safari.app")
private let notes = URL(fileURLWithPath: "/System/Applications/Notes.app")

@Test func saveThenLoadRoundTripsHistory() {
  withDefaults { defaults in
    #expect(loadLaunchHistory(from: defaults) == LaunchHistory())
    var history = LaunchHistory()
    history.recordLaunch(of: safari, at: Date(timeIntervalSince1970: 1_700_000_000))
    history.recordLaunch(of: notes, at: Date(timeIntervalSince1970: 1_700_000_500))
    saveLaunchHistory(history, to: defaults)
    let loaded = loadLaunchHistory(from: defaults)
    #expect(loaded == history)
    #expect(loaded.records.count == 2)
  }
}

@Test func recordLaunchCountsAndUpdatesTime() {
  var history = LaunchHistory()
  history.recordLaunch(of: safari, at: Date(timeIntervalSince1970: 1_700_000_000))
  history.recordLaunch(of: safari, at: Date(timeIntervalSince1970: 1_700_086_400))
  #expect(
    history.records[safari.path]
      == LaunchRecord(count: 2, lastLaunched: Date(timeIntervalSince1970: 1_700_086_400)))
}

@Test func corruptHistoryLoadsEmpty() {
  withDefaults { defaults in
    defaults.set(Data("broken".utf8), forKey: "launcher.history")
    #expect(loadLaunchHistory(from: defaults) == LaunchHistory())
    defaults.set("x", forKey: "launcher.history")
    #expect(loadLaunchHistory(from: defaults) == LaunchHistory())
  }
}

@Test func nonPositiveCountsAreDropped() {
  withDefaults { defaults in
    let json = """
      {"/Applications/Safari.app": {"count": 3, "lastLaunched": 0},
       "/Applications/Zero.app": {"count": 0, "lastLaunched": 0},
       "/Applications/Negative.app": {"count": -2, "lastLaunched": 0}}
      """
    defaults.set(Data(json.utf8), forKey: "launcher.history")
    #expect(
      loadLaunchHistory(from: defaults).records == [
        safari.path: LaunchRecord(count: 3, lastLaunched: Date(timeIntervalSinceReferenceDate: 0))
      ])
  }
}
