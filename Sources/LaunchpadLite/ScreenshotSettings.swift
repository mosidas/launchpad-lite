import Foundation

/// 浮かべた画像を出す Space。
enum SpaceMode: String, CaseIterable {
  case allSpaces, currentSpace

  var title: String {
    switch self {
    case .allSpaces: "すべての Space"
    case .currentSpace: "現在の Space だけ"
    }
  }
}

struct ScreenshotSettings: Equatable {
  /// ドラッグで動かしている間の不透明度。
  var movingOpacity: Double
  /// 新しく浮かべる画像を出す Space。
  var spaceMode: SpaceMode
}

/// 保存済みの設定を返す。保存値が無いか型が合わなければ項目ごとに既定値を使う。
func loadScreenshotSettings(from defaults: UserDefaults = .standard) -> ScreenshotSettings {
  // NaN は型違いと同じに扱う(min・max は NaN を素通しする)。
  let opacity = defaults.object(forKey: "screenshot.movingOpacity") as? Double ?? .nan
  let mode = (defaults.object(forKey: "screenshot.spaceMode") as? String).flatMap(
    SpaceMode.init(rawValue:))
  return ScreenshotSettings(
    movingOpacity: opacity.isNaN ? 0.7 : min(max(opacity, 0.1), 1),
    spaceMode: mode ?? .allSpaces)
}

/// 設定を保存する。nil なら保存値を消し、既定値に戻す。
func saveScreenshotSettings(_ settings: ScreenshotSettings?, to defaults: UserDefaults = .standard)
{
  guard let settings else {
    defaults.removeObject(forKey: "screenshot.movingOpacity")
    defaults.removeObject(forKey: "screenshot.spaceMode")
    return
  }
  defaults.set(settings.movingOpacity, forKey: "screenshot.movingOpacity")
  defaults.set(settings.spaceMode.rawValue, forKey: "screenshot.spaceMode")
}

/// 実行時の現在の設定。
@MainActor var currentScreenshotSettings = loadScreenshotSettings()
