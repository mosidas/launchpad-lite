import AppKit
import Testing

@testable import LaunchpadLite

@Test @MainActor func settingsPageTitlesAreUnique() {
  #expect(Set(settingsPages.map(\.id)).count == settingsPages.count)
}

/// 開いた設定ウィンドウのサイドバー。
@MainActor private func sidebar(of window: NSWindow) throws -> NSTableView {
  func find(_ view: NSView) -> NSTableView? {
    view as? NSTableView ?? view.subviews.lazy.compactMap(find).first
  }
  return try #require(window.contentView.flatMap(find))
}

/// 表示を反映させるため、メインの run loop を少し回す。
@MainActor private func settle() {
  RunLoop.main.run(until: Date().addingTimeInterval(0.3))
}

@Test @MainActor func switchingSettingsPagesKeepsWindowSize() throws {
  _ = NSApplication.shared
  showSettings()
  settle()
  let window = try #require(settingsWindow)
  defer { window.close() }
  let initialSize = window.frame.size
  let table = try sidebar(of: window)
  #expect(table.numberOfRows == settingsPages.count)
  for (row, page) in settingsPages.enumerated() {
    table.selectRowIndexes([row], byExtendingSelection: false)
    settle()
    #expect(window.frame.size == initialSize, "\(page.title) のページでウィンドウの大きさが変わらない")
  }
  table.deselectAll(nil)
  settle()
  #expect(table.selectedRow == settingsPages.count - 1, "選択を外しても最後に選んだページが選ばれたまま")
}
