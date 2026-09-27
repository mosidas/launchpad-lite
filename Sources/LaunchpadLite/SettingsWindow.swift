import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor var settingsWindow: NSWindow?

/// 設定ウィンドウを開く。ウィンドウは 1 つだけ作って使い回す。
@MainActor
func showSettings() {
  let window =
    settingsWindow
    ?? {
      let window = NSWindow(
        contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
      window.title = "LaunchpadLite の設定"
      window.isReleasedWhenClosed = false
      settingsWindow = window
      return window
    }()
  // 開くたびにビューを作り直し、保存値を読み直す。
  window.contentView = NSHostingView(
    rootView: TabView {
      SettingsView().tabItem { Text("ホットキー") }
      MouseSettingsView().tabItem { Text("マウス") }
    })
  window.center()
  NSApp.activate()
  window.makeKeyAndOrderFront(nil)
}

/// ホットキーの一覧。行を押してキーを押すと記録し、その場で登録し直す。
private struct SettingsView: View {
  @State private var combos = Dictionary(
    uniqueKeysWithValues: HotKeyAction.allCases.map { ($0, loadKeyCombo($0)) })
  @State private var recording: HotKeyAction?
  @State private var failed = Set<HotKeyAction>()
  @State private var monitor: Any?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Grid(alignment: .leading, verticalSpacing: 6) {
        ForEach(HotKeyAction.allCases, id: \.self) { action in
          GridRow {
            Text(action.title)
            Button(recording == action ? "キーを入力…" : combos[action]?.label ?? "") {
              startRecording(action)
            }
            .frame(minWidth: 120)
            if failed.contains(action) {
              Text("登録できない").foregroundStyle(.red)
            }
          }
        }
      }
      Text("⌘・⌃・⌥ のいずれかを含むキーを受け付ける。Escape で取り消す。")
        .font(.caption).foregroundStyle(.secondary)
      Button("既定に戻す") {
        stopRecording()
        for action in HotKeyAction.allCases { saveKeyCombo(nil, for: action) }
        combos = Dictionary(
          uniqueKeysWithValues: HotKeyAction.allCases.map { ($0, loadKeyCombo($0)) })
        failed = Set(registerAllHotKeys())
      }
    }
    .padding(20)
    .fixedSize()
    // 閉じても、他のアプリへ切り替えても、ホットキーが外れたままにならないよう記録を終える。
    // 閉じるボタンでは .onDisappear が呼ばれないので、ウィンドウの通知も受ける。
    .onDisappear { stopRecording() }
    .onReceive(
      NotificationCenter.default.publisher(
        for: NSWindow.willCloseNotification, object: settingsWindow)
    ) { _ in stopRecording() }
    .onReceive(
      NotificationCenter.default.publisher(
        for: NSWindow.didResignKeyNotification, object: settingsWindow)
    ) { _ in stopRecording() }
  }

  /// 記録中は全ホットキーを外す。外さないと、記録しようとしたキーで動作が先に起きる。
  private func startRecording(_ action: HotKeyAction) {
    stopRecording()
    unregisterAllHotKeys()
    recording = action
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let modifiers = carbonModifiers(event.modifierFlags)
      if event.keyCode == kVK_Escape && modifiers == 0 {
        stopRecording()
      } else if modifiers & UInt32(cmdKey | controlKey | optionKey) != 0 {
        // ⌘⌃⌥ のどれも含まないキーは、文字入力を奪うので受け付けない。
        let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        saveKeyCombo(combo, for: action)
        combos[action] = combo
        stopRecording()
      }
      return nil
    }
  }

  private func stopRecording() {
    guard let monitor else { return }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
    recording = nil
    failed = Set(registerAllHotKeys())
  }
}
