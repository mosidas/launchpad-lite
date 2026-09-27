import AppKit
import Carbon.HIToolbox

/// ホットキーのキーの組み合わせ。keyCode は kVK_*、modifiers は cmdKey などの和。
struct KeyCombo: Equatable, Codable {
  var keyCode: UInt32
  var modifiers: UInt32
}

/// ホットキーで起こす動作。並びは README のホットキー表の順で、添字 +1 を EventHotKeyID.id に使う。
enum HotKeyAction: String, CaseIterable {
  case launcher, screenshot
  case leftHalf, rightHalf, topHalf, bottomHalf
  case topRight, topLeft, bottomLeft, bottomRight
  case maximize, centerThreeQuarters
  case previousDisplay, nextDisplay
  case sleep

  var title: String {
    switch self {
    case .launcher: "ランチャーを開く・閉じる"
    case .screenshot: "スクリーンショットのツールバーを開く"
    case .leftHalf: "左半分"
    case .rightHalf: "右半分"
    case .topHalf: "上半分"
    case .bottomHalf: "下半分"
    case .topRight: "右上 1/4"
    case .topLeft: "左上 1/4"
    case .bottomLeft: "左下 1/4"
    case .bottomRight: "右下 1/4"
    case .maximize: "最大化"
    case .centerThreeQuarters: "中央 3/4"
    case .previousDisplay: "前のディスプレイへ移す"
    case .nextDisplay: "次のディスプレイへ移す"
    case .sleep: "スリープする"
    }
  }

  var defaultCombo: KeyCombo {
    let cmdShift = cmdKey | shiftKey
    let (keyCode, modifiers) =
      switch self {
      case .launcher: (kVK_Space, cmdKey)
      case .screenshot: (kVK_ANSI_S, cmdShift)
      case .leftHalf: (kVK_LeftArrow, cmdShift)
      case .rightHalf: (kVK_RightArrow, cmdShift)
      case .topHalf: (kVK_UpArrow, cmdShift)
      case .bottomHalf: (kVK_DownArrow, cmdShift)
      case .topRight: (kVK_ANSI_1, cmdShift)
      case .topLeft: (kVK_ANSI_2, cmdShift)
      case .bottomLeft: (kVK_ANSI_3, cmdShift)
      case .bottomRight: (kVK_ANSI_4, cmdShift)
      case .maximize: (kVK_Return, cmdShift)
      case .centerThreeQuarters: (kVK_ANSI_C, cmdShift)
      case .previousDisplay: (kVK_LeftArrow, controlKey | cmdKey)
      case .nextDisplay: (kVK_RightArrow, controlKey | cmdKey)
      case .sleep: (kVK_ANSI_S, cmdKey | optionKey)
      }
    return KeyCombo(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
  }
}

/// 保存済みの組み合わせを返す。保存値が無いか壊れていれば既定値を返す。
func loadKeyCombo(_ action: HotKeyAction, from defaults: UserDefaults = .standard) -> KeyCombo {
  guard let value = defaults.array(forKey: "hotKey.\(action.rawValue)") as? [Int], value.count == 2,
    let keyCode = UInt32(exactly: value[0]), let modifiers = UInt32(exactly: value[1])
  else { return action.defaultCombo }
  return KeyCombo(keyCode: keyCode, modifiers: modifiers)
}

/// 組み合わせを保存する。nil なら保存値を消し、既定値に戻す。
func saveKeyCombo(
  _ combo: KeyCombo?, for action: HotKeyAction, to defaults: UserDefaults = .standard
) {
  let key = "hotKey.\(action.rawValue)"
  if let combo {
    defaults.set([Int(combo.keyCode), Int(combo.modifiers)], forKey: key)
  } else {
    defaults.removeObject(forKey: key)
  }
}

/// NSEvent の修飾キーを Carbon の修飾キーの和へ写す。⌘⇧⌥⌃ 以外は無視する。
func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
  let pairs: [(NSEvent.ModifierFlags, Int)] = [
    (.command, cmdKey), (.shift, shiftKey), (.option, optionKey), (.control, controlKey),
  ]
  return pairs.reduce(0) { $0 | (flags.contains($1.0) ? UInt32($1.1) : 0) }
}

// ponytail: 文字にならないキーだけ固定表。文字は現在の配列から引く
/// F1〜F12 のキーコード。添字 + 1 がキーの番号になる。
let functionKeyCodes = [
  kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11,
  kVK_F12,
]

private let keyNames: [Int: String] = {
  var names: [Int: String] = [
    kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
    kVK_Return: "Return", kVK_Space: "Space", kVK_Tab: "Tab", kVK_Delete: "Delete",
    kVK_Escape: "Escape",
  ]
  for (i, code) in functionKeyCodes.enumerated() { names[code] = "F\(i + 1)" }
  return names
}()

extension KeyCombo {
  /// 修飾キーを ⌃⌥⇧⌘ の順に並べ、キー名を続けた表示(例 ⇧⌘←)。
  @MainActor var label: String {
    let symbols: [(Int, String)] = [
      (controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘"),
    ]
    let prefix = symbols.filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined()
    if let name = keyNames[Int(keyCode)] { return prefix + name }
    if let code = UInt16(exactly: keyCode), let character = layoutCharacter(keyCode: code),
      character.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil
    {
      return prefix + character.uppercased()
    }
    return prefix + "Key\(keyCode)"
  }
}

/// ホットキーが押されたときに呼ぶ処理。main.swift で設定する。
@MainActor var performHotKey: @MainActor (HotKeyAction) -> Void = { _ in }
@MainActor private var hotKeyRefs: [HotKeyAction: EventHotKeyRef] = [:]
@MainActor private var handlerInstalled = false

/// action のホットキーを combo で登録する。登録済みなら差し替える。失敗したら false を返す。
@MainActor
func registerHotKey(_ action: HotKeyAction, _ combo: KeyCombo) -> Bool {
  if !handlerInstalled {
    handlerInstalled = true
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, _ in
        var hotKeyID = EventHotKeyID()
        GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
          MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        MainActor.assumeIsolated {
          let actions = HotKeyAction.allCases
          let index = Int(hotKeyID.id) - 1
          if actions.indices.contains(index) { performHotKey(actions[index]) }
        }
        return noErr
      }, 1, &spec, nil, nil)
  }
  if let old = hotKeyRefs.removeValue(forKey: action) { UnregisterEventHotKey(old) }
  let id = UInt32(HotKeyAction.allCases.firstIndex(of: action)! + 1)
  var ref: EventHotKeyRef?
  let status = RegisterEventHotKey(
    combo.keyCode, combo.modifiers, EventHotKeyID(signature: OSType(0x4C50_4C54), id: id),
    GetApplicationEventTarget(), 0, &ref)
  guard status == noErr, let ref else {
    NSLog("ホットキーを登録できない(\(action.rawValue)、keyCode \(combo.keyCode)、status \(status))")
    return false
  }
  hotKeyRefs[action] = ref
  return true
}

/// 登録済みのホットキーをすべて解除する。
@MainActor
func unregisterAllHotKeys() {
  for ref in hotKeyRefs.values { UnregisterEventHotKey(ref) }
  hotKeyRefs.removeAll()
}

/// 全動作を保存済みまたは既定の組み合わせで登録し直し、登録に失敗した動作を返す。
@MainActor @discardableResult
func registerAllHotKeys() -> [HotKeyAction] {
  unregisterAllHotKeys()
  return HotKeyAction.allCases.filter { !registerHotKey($0, loadKeyCombo($0)) }
}
