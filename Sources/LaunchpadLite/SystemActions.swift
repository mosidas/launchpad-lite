import AppKit
import Carbon.HIToolbox
import IOKit.hidsystem

/// 外部コマンドを起動し、終了を待たずに戻る。
func run(_ path: String, _ args: [String]) {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: path)
  process.arguments = args
  try? process.run()
}

/// スクリーンショットのツールバーを開く(⌘⇧5 と同じ)。保存先や形式は OS の設定に従う。
func openScreenshotToolbar() {
  NSWorkspace.shared.openApplication(
    at: URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"),
    configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
}

func sleepNow() { run("/usr/bin/pmset", ["sleepnow"]) }

/// キーの組み合わせを押して離す。
func postKey(_ combo: KeyCombo) {
  for down in [true, false] {
    let event = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(combo.keyCode), keyDown: down)
    event?.flags = keyEventFlags(combo)
    event?.post(tap: .cghidEventTap)
  }
}

/// メディアキー(NX_KEYTYPE_*)を押して離す。
func postMediaKey(_ key: Int32) {
  for down in [true, false] {
    NSEvent.otherEvent(
      with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
      context: nil, subtype: 8, data1: mediaKeyData1(key, down: down), data2: -1)?.cgEvent?.post(
        tap: .cghidEventTap)
  }
}

/// 現在のカーソル位置でマウスのボタン(0 始まりの番号)をクリックする。自分の tap が素通しするよう印を付ける。
func postMouseButton(_ number: Int) {
  let location = CGEvent(source: nil)?.location ?? .zero
  for type in [CGEventType.otherMouseDown, .otherMouseUp] {
    let event = CGEvent(
      mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .center)
    event?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(number))
    event?.setIntegerValueField(.eventSourceUserData, value: syntheticEventMark)
    event?.post(tap: .cghidEventTap)
  }
}

/// マウスの割り当てを実行する。
@MainActor func perform(_ action: MouseAction) {
  let missionControl = "/System/Applications/Mission Control.app/Contents/MacOS/Mission Control"
  switch action {
  case .shortcut(let combo): postKey(combo)
  case .system(let system):
    switch system {
    case .back, .forward:
      let isBack = system == .back
      if usesNavigationKeys(bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
        let key =
          isBack
          ? keyCode(for: "[") ?? UInt32(kVK_ANSI_LeftBracket)
          : keyCode(for: "]") ?? UInt32(kVK_ANSI_RightBracket)
        postKey(KeyCombo(keyCode: key, modifiers: UInt32(cmdKey)))
      } else {
        postMouseButton(isBack ? 3 : 4)
      }
    case .missionControl: run(missionControl, [])
    case .appExpose: run(missionControl, ["2"])
    case .showDesktop: run(missionControl, ["1"])
    case .launchpad:
      let workspace = NSWorkspace.shared
      if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.apps.launcher")
        ?? workspace.urlForApplication(withBundleIdentifier: "com.apple.launchpad.launcher")
      {
        workspace.openApplication(
          at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
      }
    case .spaceLeft:
      postKey(KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(controlKey)))
    case .spaceRight:
      postKey(KeyCombo(keyCode: UInt32(kVK_RightArrow), modifiers: UInt32(controlKey)))
    case .volumeUp: postMediaKey(NX_KEYTYPE_SOUND_UP)
    case .volumeDown: postMediaKey(NX_KEYTYPE_SOUND_DOWN)
    case .mute: postMediaKey(NX_KEYTYPE_MUTE)
    case .playPause: postMediaKey(NX_KEYTYPE_PLAY)
    }
  }
}
