import Foundation

struct AppEntry: Equatable {
  let name: String
  let url: URL
}

/// 検索対象のディレクトリ。英語のファイル名だけを扱い、ローカライズ名は扱わない。
let applicationDirectories = [
  URL(fileURLWithPath: "/Applications"),
  URL(fileURLWithPath: "/System/Applications"),
  FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
]

/// query が candidate の部分列なら、一致の良さを返す(大きいほど良い)。部分列でなければ nil。
/// 先頭一致・単語の先頭での一致・連続した一致に加点し、一致の間の空き文字数だけ減点する。
/// 全ての一致位置の取り方から最高点を選ぶ(DP)。
func fuzzyScore(query: String, candidate: String) -> Int? {
  let q = query.map { $0.lowercased() }
  let original = Array(candidate)
  let c = original.map { $0.lowercased() }
  guard !q.isEmpty else { return 0 }

  func bonus(_ j: Int) -> Int {
    if j == 0 { return 15 }
    let prev = original[j - 1]
    if " -.".contains(prev) || (original[j].isUppercase && !prev.isUppercase) { return 10 }
    return 0
  }

  // best[j]: q の現在の文字までを、現在の文字を c[j] に一致させて並べたときの最高点
  var best: [Int?] = c.indices.map { c[$0] == q[0] ? 1 + bonus($0) : nil }
  for i in 1..<q.count {
    var next = [Int?](repeating: nil, count: c.count)
    for j in c.indices where c[j] == q[i] {
      for k in 0..<j {
        guard let s = best[k] else { continue }
        let total = s + 1 + bonus(j) + (k == j - 1 ? 5 : -(j - k - 1))
        next[j] = max(next[j] ?? total, total)
      }
    }
    best = next
  }
  return best.compactMap { $0 }.max()
}

/// query が空なら名前順に全件を返す。空でなければ一致したものをスコア降順・名前の短い順・名前順で返す。
func rank(query: String, apps: [AppEntry]) -> [AppEntry] {
  let byName = { (a: AppEntry, b: AppEntry) in
    a.name.localizedStandardCompare(b.name) == .orderedAscending
  }
  if query.isEmpty { return apps.sorted(by: byName) }
  return apps.compactMap { app in fuzzyScore(query: query, candidate: app.name).map { (app, $0) } }
    .sorted { a, b in
      if a.1 != b.1 { return a.1 > b.1 }
      if a.0.name.count != b.0.name.count { return a.0.name.count < b.0.name.count }
      return byName(a.0, b.0)
    }
    .map(\.0)
}

/// dirs の下を走査して .app を集める。.app の中は見ない。同名は先に見つかったほうを残す。
func scanApplications(in dirs: [URL]) -> [AppEntry] {
  var seen = Set<String>()
  var result: [AppEntry] = []
  for dir in dirs {
    guard
      let items = FileManager.default.enumerator(
        at: dir, includingPropertiesForKeys: nil,
        options: [.skipsPackageDescendants, .skipsHiddenFiles])
    else { continue }
    for case let url as URL in items where url.pathExtension == "app" {
      let name = url.deletingPathExtension().lastPathComponent
      if seen.insert(name).inserted { result.append(AppEntry(name: name, url: url)) }
    }
  }
  return result
}
