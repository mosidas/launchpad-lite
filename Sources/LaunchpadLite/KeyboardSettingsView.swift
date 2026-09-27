import AppKit
import Carbon.HIToolbox
import SwiftUI

/// キーボードの設定。変えるとその場で保存し、適用する。
struct KeyboardSettingsView: View {
  @State private var settings = loadKeyboardSettings()
  /// キーを記録中の F の番号。
  @State private var recording: Int?
  @State private var monitor: Any?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Form {
        Section("ファンクションキー") {
          ForEach(1...12, id: \.self) { number in
            LabeledContent("F\(number)") {
              HStack {
                ActionPicker(selection: choice(for: number))
                if recording == number {
                  Button("キーを入力…") { startRecording(number) }
                } else if case .shortcut(let combo) = settings.functionKeys[number] {
                  Button(combo.label) { startRecording(number) }
                }
              }
            }
          }
        }
      }
      Text("修飾キーの無い F キーだけを置き換える。キーの入力中は修飾キーの無いキーも受け付ける。Escape で取り消す。")
        .font(.caption).foregroundStyle(.secondary)
      Button("既定に戻す") {
        stopRecording()
        saveKeyboardSettings(nil)
        settings = loadKeyboardSettings()
      }
    }
    .padding(20)
    .fixedSize()
    .onChange(of: settings) {
      saveKeyboardSettings(settings)
      currentKeyboardSettings = settings
    }
    // MouseSettingsView と同じく、閉じる・他のアプリへ切り替える・タブを離れるときに記録を終える。
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

  /// 「なし」は割り当てを外し、ショートカットはキーの記録を始める。
  private func choice(for number: Int) -> Binding<ActionChoice> {
    Binding {
      if recording == number { return .shortcut }
      switch settings.functionKeys[number] {
      case nil: return .none
      case .shortcut: return .shortcut
      case .system(let action): return .system(action)
      }
    } set: { choice in
      switch choice {
      case .none:
        if recording == number { stopRecording() }
        settings.functionKeys[number] = nil
      case .system(let action):
        if recording == number { stopRecording() }
        settings.functionKeys[number] = .system(action)
      case .shortcut:
        if case .shortcut = settings.functionKeys[number] { return }
        startRecording(number)
      }
    }
  }

  /// 記録中は tap とホットキーを止める。止めないと、押したキーで割り当ての動作が先に起きる。
  private func startRecording(_ number: Int) {
    stopRecording()
    setMouseEventTapEnabled(false)
    unregisterAllHotKeys()
    recording = number
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let modifiers = carbonModifiers(event.modifierFlags)
      if !(event.keyCode == kVK_Escape && modifiers == 0) {
        let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        settings.functionKeys[number] = .shortcut(combo)
      }
      stopRecording()
      return nil
    }
  }

  private func stopRecording() {
    guard let monitor else { return }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
    recording = nil
    setMouseEventTapEnabled(true)
    registerAllHotKeys()
  }
}
