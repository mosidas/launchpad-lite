import AppKit
import ServiceManagement

/// メニューバーのアイコンとメニュー。ログイン時起動の切り替え・設定・終了を置く。
@MainActor
final class MenuBar: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let loginItem = NSMenuItem(
    title: "ログイン時に起動", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")

  override init() {
    super.init()
    statusItem.button?.image = NSImage(
      systemSymbolName: "square.grid.3x3", accessibilityDescription: "LaunchpadLite")

    let menu = NSMenu()
    menu.delegate = self
    loginItem.target = self
    menu.addItem(loginItem)
    let settingsItem = NSMenuItem(
      title: "設定…", action: #selector(openSettings(_:)), keyEquivalent: ",")
    settingsItem.target = self
    menu.addItem(settingsItem)
    menu.addItem(.separator())
    let quitItem = NSMenuItem(
      title: "LaunchpadLite を終了", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    quitItem.target = NSApp
    menu.addItem(quitItem)
    statusItem.menu = menu
  }

  // 状態はアプリ側に持たず、開くたびに OS から読む。システム設定側で外されても表示がずれない。
  func menuNeedsUpdate(_ menu: NSMenu) {
    loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
  }

  @objc private func openSettings(_ sender: NSMenuItem) {
    showSettings()
  }

  @objc private func toggleLoginItem(_ sender: NSMenuItem) {
    let service = SMAppService.mainApp
    do {
      if service.status == .enabled {
        try service.unregister()
      } else {
        try service.register()
        if service.status == .requiresApproval {
          SMAppService.openSystemSettingsLoginItems()
        }
      }
    } catch {
      // .app 以外(swift run など)から起動したときはここに来る。
      NSApp.activate()
      NSAlert(error: error).runModal()
    }
  }
}
