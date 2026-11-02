import Foundation

struct LaunchRecord: Equatable, Codable {
  var count: Int
  var lastLaunched: Date
}

/// ランチャーから起動したアプリの回数と最後の起動時刻。キーは .app のパス。
struct LaunchHistory: Equatable {
  var records: [String: LaunchRecord] = [:]

  /// 起動回数を、最後の起動からの経過日数で減衰させた値。履歴が無ければ 0。
  func frecency(of app: AppEntry, now: Date) -> Double {
    guard let record = records[app.url.path] else { return 0 }
    // shortcut: 半減期 7 日は根拠のない仮の値。並びが利用者の感覚と合わないという声が出たら起動の記録から決め直す
    let days = now.timeIntervalSince(record.lastLaunched) / 86_400
    return Double(record.count) * pow(0.5, days / 7)
  }

  mutating func recordLaunch(of url: URL, at date: Date) {
    records[url.path, default: LaunchRecord(count: 0, lastLaunched: date)].count += 1
    records[url.path]?.lastLaunched = date
  }
}

private let historyKey = "launcher.history"

/// 保存済みの履歴を返す。保存値が無ければ空、読めなければログに残して空にする。回数が 1 未満の項目は捨てる。
func loadLaunchHistory(from defaults: UserDefaults = .standard) -> LaunchHistory {
  guard let stored = defaults.object(forKey: historyKey) else { return LaunchHistory() }
  guard let data = stored as? Data,
    let records = try? JSONDecoder().decode([String: LaunchRecord].self, from: data)
  else {
    NSLog("LaunchpadLite: 起動履歴を読めないので空にした")
    return LaunchHistory()
  }
  return LaunchHistory(records: records.filter { $0.value.count >= 1 })
}

func saveLaunchHistory(_ history: LaunchHistory, to defaults: UserDefaults = .standard) {
  defaults.set(try? JSONEncoder().encode(history.records), forKey: historyKey)
}

/// 実行時の起動履歴。
@MainActor var currentLaunchHistory = loadLaunchHistory()
