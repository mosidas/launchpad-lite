import AppKit
import Carbon.HIToolbox
import SwiftUI

/// 修飾キーごとの、左右を区別するデバイスのフラグ(NX_DEVICE*KEYMASK)。flagsChanged が押下か離しかを見分ける。
private let modifierMasks: [Int: UInt] = [
  kVK_Control: 0x1, kVK_RightControl: 0x2000, kVK_Shift: 0x2, kVK_RightShift: 0x4,
  kVK_Option: 0x20, kVK_RightOption: 0x40, kVK_Command: 0x8, kVK_RightCommand: 0x10,
]

/// キーボードの設定。変えるとその場で保存し、適用する。
struct KeyboardSettingsView: View {
  /// キーを記録中の対象。F キーのショートカット、置き換えの元のキー、置き換え先(元のキーを持つ)。
  enum Recording: Equatable {
    case functionKey(Int)
    case remapFrom
    case remapTo(UInt32)
  }

  @State private var settings = loadKeyboardSettings()
  @State private var recording: Recording?
  @State private var monitor: Any?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Form {
        Section("ファンクションキー") {
          ForEach(1...12, id: \.self) { number in
            LabeledContent("F\(number)") {
              HStack {
                ActionPicker(selection: choice(for: number))
                if recording == .functionKey(number) {
                  Button("キーを入力…") { startRecording(.functionKey(number)) }
                } else if case .shortcut(let combo) = settings.functionKeys[number] {
                  Button(combo.label) { startRecording(.functionKey(number)) }
                }
              }
            }
          }
        }
        Section("キーの置き換え") {
          ForEach(settings.remaps, id: \.from) { remap in
            LabeledContent(KeyCombo(keyCode: remap.from, modifiers: 0).label) {
              HStack {
                Button(
                  recording == .remapTo(remap.from)
                    ? "キーを入力…" : KeyCombo(keyCode: remap.to, modifiers: 0).label
                ) { startRecording(.remapTo(remap.from)) }
                Button("削除") {
                  if recording == .remapTo(remap.from) { stopRecording() }
                  settings.remaps.removeAll { $0.from == remap.from }
                }
              }
            }
          }
          Button(addButtonTitle) { startRecording(.remapFrom) }
        }
      }
      Text(
        "F キーの割り当ては修飾キーの無い押下だけに効く。キーの入力中は修飾キーの無いキーも受け付け、置き換えでは Caps Lock や修飾キーも押せる。Escape で取り消す。キーの置き換えは LaunchpadLite を終了すると解除する。"
      )
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
      applyKeyRemaps(settings)
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
      if recording == .functionKey(number) { return .shortcut }
      switch settings.functionKeys[number] {
      case nil: return .none
      case .shortcut: return .shortcut
      case .system(let action): return .system(action)
      }
    } set: { choice in
      switch choice {
      case .none:
        if recording == .functionKey(number) { stopRecording() }
        settings.functionKeys[number] = nil
      case .system(let action):
        if recording == .functionKey(number) { stopRecording() }
        settings.functionKeys[number] = .system(action)
      case .shortcut:
        if case .shortcut = settings.functionKeys[number] { return }
        startRecording(.functionKey(number))
      }
    }
  }

  /// 「キーを追加」の表示。記録中は次に押すキーを示す。
  private var addButtonTitle: String {
    switch recording {
    case .remapFrom: return "元のキーを入力…"
    case .remapTo(let from) where !settings.remaps.contains { $0.from == from }:
      return "\(KeyCombo(keyCode: from, modifiers: 0).label) → 置き換え先を入力…"
    default: return "キーを追加"
    }
  }

  /// 記録中は tap・ホットキー・キーの置き換えを止める。止めないと、押したキーで割り当ての動作が先に起きたり、
  /// 置き換え後のキーが記録されたりする。
  private func startRecording(_ target: Recording) {
    stopRecording()
    setMouseEventTapEnabled(false)
    unregisterAllHotKeys()
    setKeyRemapsEnabled(false)
    recording = target
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
      record(event)
      return nil
    }
  }

  private func record(_ event: NSEvent) {
    let keyCode = UInt32(event.keyCode)
    let modifiers = carbonModifiers(event.modifierFlags)
    if event.type == .keyDown && event.keyCode == kVK_Escape && modifiers == 0 {
      stopRecording()
      return
    }
    // flagsChanged は修飾キーの押下と離しの両方で届く。押下(そのキーのデバイスのフラグが立っている)だけを取る。
    // Caps Lock はロックの切り替えごとに届くので、どれも押下として取る。
    if event.type == .flagsChanged && keyCode != UInt32(kVK_CapsLock) {
      guard let mask = modifierMasks[Int(keyCode)], event.modifierFlags.rawValue & mask != 0
      else { return }
    }
    switch recording {
    case .functionKey(let number):
      guard event.type == .keyDown else { return }
      settings.functionKeys[number] = .shortcut(KeyCombo(keyCode: keyCode, modifiers: modifiers))
      stopRecording()
    case .remapFrom:
      guard hidUsage(keyCode: keyCode) != nil else { return }
      recording = .remapTo(keyCode)
    case .remapTo(let from):
      // 元のキーのキーリピートや離し(Caps Lock)も届くので、元と同じキーは無視して記録を続ける。
      guard hidUsage(keyCode: keyCode) != nil, keyCode != from else { return }
      if let index = settings.remaps.firstIndex(where: { $0.from == from }) {
        settings.remaps[index].to = keyCode
      } else {
        settings.remaps.append(KeyRemap(from: from, to: keyCode))
      }
      stopRecording()
    case nil: return
    }
  }

  private func stopRecording() {
    guard let monitor else { return }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
    recording = nil
    setMouseEventTapEnabled(true)
    registerAllHotKeys()
    setKeyRemapsEnabled(true)
  }
}
