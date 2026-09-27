import Foundation

/// マウスのボタンやサムホイールに割り当てるシステム操作。
enum SystemAction: String, CaseIterable, Codable {
  case back, forward, missionControl, appExpose, showDesktop, launchpad, spaceLeft, spaceRight
  case volumeUp, volumeDown, mute, playPause

  var title: String {
    switch self {
    case .back: "戻る"
    case .forward: "進む"
    case .missionControl: "Mission Control"
    case .appExpose: "アプリケーション Exposé"
    case .showDesktop: "デスクトップを表示"
    case .launchpad: "Launchpad"
    case .spaceLeft: "左の Space へ"
    case .spaceRight: "右の Space へ"
    case .volumeUp: "音量を上げる"
    case .volumeDown: "音量を下げる"
    case .mute: "消音"
    case .playPause: "再生/一時停止"
    }
  }
}

/// 割り当ての対象。button の値は CGEvent の mouseEventButtonNumber(0 始まり)。
enum MouseTrigger: Hashable, Codable {
  case button(Int)
  case thumbLeft, thumbRight

  var title: String {
    switch self {
    case .button(let n): "ボタン \(n + 1)"
    case .thumbLeft: "サムホイール左"
    case .thumbRight: "サムホイール右"
    }
  }
}

enum MouseAction: Equatable, Codable {
  case shortcut(KeyCombo)
  case system(SystemAction)
}

struct MouseBinding: Equatable, Codable {
  var trigger: MouseTrigger
  var action: MouseAction
}

struct MouseSettings: Equatable {
  var pointerAcceleration: Bool
  var pointerSpeed: Double
  var reverseVertical: Bool
  var reverseHorizontal: Bool
  var scrollLines: Int
  var bindings: [MouseBinding]

  /// trigger に最初に一致する割り当ての動作。
  func action(for trigger: MouseTrigger) -> MouseAction? {
    bindings.first { $0.trigger == trigger }?.action
  }
}

private let defaultBindings = [
  MouseBinding(trigger: .button(3), action: .system(.back)),
  MouseBinding(trigger: .button(4), action: .system(.forward)),
]

/// 保存済みの設定を返す。保存値が無いか型が合わなければ項目ごとに既定値を使う。
/// ポインタの既定値はシステム設定(グローバルドメイン)の値。
func loadMouseSettings(from defaults: UserDefaults = .standard) -> MouseSettings {
  func value<T>(_ key: String, _ fallback: T) -> T {
    defaults.object(forKey: key) as? T ?? fallback
  }
  let bindings = defaults.data(forKey: "mouse.bindings").flatMap {
    try? JSONDecoder().decode([MouseBinding].self, from: $0)
  }
  // NaN は型違いと同じに扱う(min・max は NaN を素通しする)。
  let scaling = value("com.apple.mouse.scaling", 1.0)
  let systemSpeed = scaling.isNaN ? 1.0 : scaling
  let speed = value("mouse.pointerSpeed", systemSpeed)
  return MouseSettings(
    pointerAcceleration: value(
      "mouse.pointerAcceleration", !value("com.apple.mouse.linear", false)),
    pointerSpeed: min(max(speed.isNaN ? systemSpeed : speed, 0.1), 3),
    reverseVertical: value("mouse.reverseVertical", false),
    reverseHorizontal: value("mouse.reverseHorizontal", true),
    scrollLines: min(max(value("mouse.scrollLines", 4), 1), 20),
    bindings: bindings ?? defaultBindings)
}

/// 設定を保存する。nil なら保存値を消し、既定値に戻す。
func saveMouseSettings(_ settings: MouseSettings?, to defaults: UserDefaults = .standard) {
  guard let settings else {
    for key in [
      "pointerAcceleration", "pointerSpeed", "reverseVertical", "reverseHorizontal",
      "scrollLines", "bindings",
    ] {
      defaults.removeObject(forKey: "mouse.\(key)")
    }
    return
  }
  defaults.set(settings.pointerAcceleration, forKey: "mouse.pointerAcceleration")
  defaults.set(settings.pointerSpeed, forKey: "mouse.pointerSpeed")
  defaults.set(settings.reverseVertical, forKey: "mouse.reverseVertical")
  defaults.set(settings.reverseHorizontal, forKey: "mouse.reverseHorizontal")
  defaults.set(settings.scrollLines, forKey: "mouse.scrollLines")
  defaults.set(try? JSONEncoder().encode(settings.bindings), forKey: "mouse.bindings")
}

/// 実行時の現在の設定。
@MainActor var currentMouseSettings = loadMouseSettings()
