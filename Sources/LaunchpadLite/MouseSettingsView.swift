import AppKit
import Carbon.HIToolbox
import SwiftUI

/// マウスの設定。変えるとその場で保存し、適用する。
struct MouseSettingsView: View {
  private enum Choice: Hashable {
    case none, shortcut
    case system(SystemAction)
  }

  private enum Recording: Equatable {
    case button
    case key(MouseTrigger)
  }

  @State private var settings = loadMouseSettings()
  /// この画面で記録したが、まだ割り当てていないボタン。
  @State private var recordedButtons = Set<Int>()
  @State private var recording: Recording?
  @State private var monitor: Any?

  private var triggers: [MouseTrigger] {
    let buttons = Set(
      settings.bindings.compactMap {
        if case .button(let n) = $0.trigger { n } else { nil }
      }
    ).union(recordedButtons)
    return [.thumbLeft, .thumbRight] + buttons.sorted().map { .button($0) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Form {
        Section("ポインタ") {
          Toggle("ポインタの加速", isOn: $settings.pointerAcceleration)
          LabeledContent("ポインタの速度") {
            HStack {
              Slider(value: $settings.pointerSpeed, in: 0.1...3)
              valueLabel(settings.pointerSpeed.formatted(.number.precision(.fractionLength(1))))
            }
          }
        }
        Section("ホイール") {
          Toggle("縦のスクロールを反転する", isOn: $settings.reverseVertical)
          Toggle("横のスクロールを反転する", isOn: $settings.reverseHorizontal)
          LabeledContent("スクロールの行数") {
            HStack {
              Slider(value: scrollLines, in: 1...20, step: 1)
              valueLabel("\(settings.scrollLines)")
            }
          }
        }
        Section("ボタンの割り当て") {
          ForEach(triggers, id: \.self) { trigger in
            LabeledContent(trigger.title) {
              HStack {
                Picker("", selection: choice(for: trigger)) {
                  Text("なし").tag(Choice.none)
                  ForEach(SystemAction.allCases, id: \.self) { action in
                    Text(action.title).tag(Choice.system(action))
                  }
                  Text("キーボードショートカット").tag(Choice.shortcut)
                }
                .labelsHidden()
                .fixedSize()
                if recording == .key(trigger) {
                  Button("キーを入力…") { startRecording(.key(trigger)) }
                } else if case .shortcut(let combo) = settings.action(for: trigger) {
                  Button(combo.label) { startRecording(.key(trigger)) }
                }
              }
            }
          }
          Button(recording == .button ? "マウスのボタンを押す…" : "ボタンを記録") {
            if recording == .button { stopRecording() } else { startRecording(.button) }
          }
        }
      }
      Text("ボタンはこのウィンドウの上で押す。キーの入力中は修飾キーの無いキーも受け付ける。Escape で取り消す。")
        .font(.caption).foregroundStyle(.secondary)
      Button("既定に戻す") {
        stopRecording()
        recordedButtons = []
        saveMouseSettings(nil)
        settings = loadMouseSettings()
      }
    }
    .padding(20)
    .fixedSize()
    .onChange(of: settings) {
      // 既定と同じ値は保存しない。保存すると、既定に戻した直後のポインタの値がシステム設定に追従しなくなる。
      if settings != loadMouseSettings() { saveMouseSettings(settings) }
      currentMouseSettings = settings
      applyPointerSettings(settings)
    }
    // SettingsView と同じく、閉じる・他のアプリへ切り替える・タブを離れるときに記録を終える。
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

  /// Slider の横に置く値。桁数で Slider の幅が変わらないよう、幅を固定する。
  private func valueLabel(_ text: String) -> some View {
    Text(text).monospacedDigit().frame(width: 32, alignment: .trailing)
  }

  /// Slider は Double を扱うので、Int の行数を仲介する。
  private var scrollLines: Binding<Double> {
    Binding {
      Double(settings.scrollLines)
    } set: {
      settings.scrollLines = Int($0.rounded())
    }
  }

  /// 「なし」は割り当てを外し、ショートカットはキーの記録を始める。
  private func choice(for trigger: MouseTrigger) -> Binding<Choice> {
    Binding {
      if recording == .key(trigger) { return .shortcut }
      switch settings.action(for: trigger) {
      case nil: return .none
      case .shortcut: return .shortcut
      case .system(let action): return .system(action)
      }
    } set: { choice in
      switch choice {
      case .none:
        if recording == .key(trigger) { stopRecording() }
        setAction(nil, for: trigger)
      case .system(let action):
        if recording == .key(trigger) { stopRecording() }
        setAction(.system(action), for: trigger)
      case .shortcut:
        if case .shortcut = settings.action(for: trigger) { return }
        startRecording(.key(trigger))
      }
    }
  }

  private func setAction(_ action: MouseAction?, for trigger: MouseTrigger) {
    settings.bindings.removeAll { $0.trigger == trigger }
    if let action { settings.bindings.append(MouseBinding(trigger: trigger, action: action)) }
  }

  /// 記録中は tap とホットキーを止める。止めないと、押したボタンやキーで割り当ての動作が先に起きる。
  private func startRecording(_ target: Recording) {
    stopRecording()
    setMouseEventTapEnabled(false)
    unregisterAllHotKeys()
    recording = target
    let mask: NSEvent.EventTypeMask = target == .button ? .otherMouseDown : .keyDown
    monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
      switch target {
      case .button:
        recordedButtons.insert(event.buttonNumber)
      case .key(let trigger):
        let modifiers = carbonModifiers(event.modifierFlags)
        if !(event.keyCode == kVK_Escape && modifiers == 0) {
          let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
          setAction(.shortcut(combo), for: trigger)
        }
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
