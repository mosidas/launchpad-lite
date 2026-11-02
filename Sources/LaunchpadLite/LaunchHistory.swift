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
    // 時計を戻した後は lastLaunched が now より未来になる。未来の記録は今の起動と同じに数える。
    let days = max(0, now.timeIntervalSince(record.lastLaunched) / 86_400)
    return Double(record.count) * pow(0.5, days / 7)
  }

  mutating func recordLaunch(of url: URL, at date: Date) {
    let count = records[url.path]?.count ?? 0
    records[url.path] = LaunchRecord(count: count + 1, lastLaunched: date)
  }
}

private let historyKey = "launcher.history"

/// 保存値は書き換えられうるので、読むときに回数をこの上限に寄せる(Int.max から数えて溢れないように)。
private let maxLoadedCount = 1_000_000

/// 保存済みの履歴を返す。保存値が無ければ空、読めなければログに残して空にする。回数が 1 未満の項目は捨て、上限を超える回数は上限に寄せる。
func loadLaunchHistory(from defaults: UserDefaults = .standard) -> LaunchHistory {
  guard let stored = defaults.object(forKey: historyKey) else { return LaunchHistory() }
  guard let data = stored as? Data,
    let records = try? JSONDecoder().decode([String: LaunchRecord].self, from: data)
  else {
    NSLog("LaunchpadLite: 起動履歴を読めないので空にした")
    return LaunchHistory()
  }
  return LaunchHistory(
    records:
      records.filter { $0.value.count >= 1 }.mapValues {
        LaunchRecord(count: min($0.count, maxLoadedCount), lastLaunched: $0.lastLaunched)
      })
}

func saveLaunchHistory(_ history: LaunchHistory, to defaults: UserDefaults = .standard) {
  defaults.set(try? JSONEncoder().encode(history.records), forKey: historyKey)
}

/// 実行時の起動履歴。
@MainActor var currentLaunchHistory = loadLaunchHistory()
