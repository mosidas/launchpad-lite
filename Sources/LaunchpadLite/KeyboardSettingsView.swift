import AppKit
import Carbon.HIToolbox
import SwiftUI

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
  /// 置き換え先の記録中に押している修飾キー。離したときにまだこれなら、修飾キー単独を置き換え先にする。
  @State private var pendingModifier: UInt32?

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
                    ? "キーを入力…" : KeyCombo(keyCode: remap.to, modifiers: remap.toModifiers).label
                ) {
                  if recording == .remapTo(remap.from) {
                    stopRecording()
                  } else {
                    startRecording(.remapTo(remap.from))
                  }
                }
                Toggle("日本語入力のときだけ", isOn: japaneseOnly(for: remap.from))
                  .toggleStyle(.checkbox)
                  .disabled(
                    !KeyRemap(
                      from: remap.from, to: remap.to, toModifiers: remap.toModifiers,
                      onlyJapaneseInput: true
                    ).isValid)
                Button("削除") {
                  if recording == .remapTo(remap.from) { stopRecording() }
                  settings.remaps.removeAll { $0.from == remap.from }
                }
              }
            }
          }
          Button(addButtonTitle) {
            if isAddingRemap { stopRecording() } else { startRecording(.remapFrom) }
          }
        }
      }
      Text(
        "F キーの割り当ては修飾キーの無い押下だけに効く。キーの入力中は修飾キーの無いキーも受け付け、F キーは Escape で取り消す。置き換えでは Caps Lock・修飾キー・Escape も押せ、記録中のボタンをもう一度押すと取り消す。置き換え先は修飾キーを押しながら押してもよく、修飾キー単独の置き換え先は押して離すと記録する。修飾キー付きの置き換え先と「日本語入力のときだけ」は修飾キー・Caps Lock 以外のキーにだけ使え、⌘⌃⌥⇧ を押しながら押すと元のキーが届く。キーの置き換えは LaunchpadLite を終了すると解除する。"
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

  private func japaneseOnly(for from: UInt32) -> Binding<Bool> {
    Binding {
      settings.remaps.first { $0.from == from }?.onlyJapaneseInput ?? false
    } set: { isOn in
      guard let index = settings.remaps.firstIndex(where: { $0.from == from }) else { return }
      settings.remaps[index].onlyJapaneseInput = isOn
    }
  }

  /// 「キーを追加」から始めた記録の途中か。
  private var isAddingRemap: Bool {
    switch recording {
    case .remapFrom: true
    case .remapTo(let from): !settings.remaps.contains { $0.from == from }
    default: false
    }
  }

  /// 「キーを追加」の表示。記録中は次に押すキーを示す。
  private var addButtonTitle: String {
    switch recording {
    case .remapFrom: "元のキーを入力…"
    case .remapTo(let from) where isAddingRemap:
      "\(KeyCombo(keyCode: from, modifiers: 0).label) → 置き換え先を入力…"
    default: "キーを追加"
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
    pendingModifier = nil
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
      record(event)
      return nil
    }
  }

  private func record(_ event: NSEvent) {
    let keyCode = UInt32(event.keyCode)
    let modifiers = carbonModifiers(event.modifierFlags)
    // 置き換えでは Escape も置き換えの対象になるので、Escape で取り消すのは F キーの記録だけにする。
    if case .functionKey = recording, event.type == .keyDown, event.keyCode == kVK_Escape,
      modifiers == 0
    {
      stopRecording()
      return
    }
    // flagsChanged は修飾キーの押下と離しの両方で届く。押下はそのキーのデバイスのフラグが立っている。
    // Caps Lock はロックの切り替えごとに届くので、どれも押下として扱う。
    let isRelease =
      event.type == .flagsChanged && keyCode != UInt32(kVK_CapsLock)
      && modifierMasks[Int(keyCode)].map { event.modifierFlags.rawValue & $0 == 0 } ?? true
    switch recording {
    case .functionKey(let number):
      guard event.type == .keyDown else { return }
      settings.functionKeys[number] = .shortcut(KeyCombo(keyCode: keyCode, modifiers: modifiers))
      stopRecording()
    case .remapFrom:
      guard !isRelease, hidUsage(keyCode: keyCode) != nil else { return }
      recording = .remapTo(keyCode)
    case .remapTo(let from):
      // 修飾キーは、押したまま別のキーを押せば修飾キー付きの置き換え先、そのまま離せば修飾キー単独の置き換え先にする。
      let (to, toModifiers): (UInt32, UInt32)
      if event.type == .keyDown {
        pendingModifier = nil
        (to, toModifiers) = (keyCode, modifiers)
      } else if keyCode == UInt32(kVK_CapsLock) || (isRelease && keyCode == pendingModifier) {
        (to, toModifiers) = (keyCode, 0)
      } else {
        if !isRelease { pendingModifier = keyCode }
        return
      }
      // 元のキーのキーリピートや離し(Caps Lock)も届くので、元と同じキーは無視して記録を続ける。
      guard hidUsage(keyCode: to) != nil, to != from || toModifiers != 0 else { return }
      let index = settings.remaps.firstIndex { $0.from == from }
      var remap = KeyRemap(
        from: from, to: to, toModifiers: toModifiers,
        onlyJapaneseInput: index.map { settings.remaps[$0].onlyJapaneseInput } ?? false)
      if !remap.isValid { remap.onlyJapaneseInput = false }
      // Caps Lock や修飾キーに修飾キー付きの置き換え先を選んだときなど、使えない組は記録を続ける。
      guard remap.isValid else { return }
      if let index {
        settings.remaps[index] = remap
      } else {
        settings.remaps.append(remap)
      }
      stopRecording()
      // 元のキーとして押した Caps Lock でロックが点いたままになるので消す。
      if from == UInt32(kVK_CapsLock) && NSEvent.modifierFlags.contains(.capsLock) {
        setCapsLockState(false)
      }
    case nil: return
    }
  }

  private func stopRecording() {
    guard let monitor else { return }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
    recording = nil
    pendingModifier = nil
    setMouseEventTapEnabled(true)
    registerAllHotKeys()
    setKeyRemapsEnabled(true)
  }
}
