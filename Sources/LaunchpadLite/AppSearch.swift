import Foundation

struct AppEntry: Equatable {
  /// Finder の表示名(ローカライズ名)
  let name: String
  /// 拡張子を除いたファイル名
  let fileName: String
  let url: URL
}

/// 検索対象の置き場所と、そこでの集め方。
enum AppSource {
  /// 下の階層まで、すべての .app を集める。
  case applications(URL)
  /// 直下だけを見て、利用者が起動する .app に絞る。
  case systemComponents(URL)
}

let appSources: [AppSource] = [
  .applications(URL(fileURLWithPath: "/Applications")),
  .applications(URL(fileURLWithPath: "/System/Applications")),
  .applications(
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")),
  .systemComponents(URL(fileURLWithPath: "/System/Library/CoreServices")),
  .systemComponents(URL(fileURLWithPath: "/System/Library/CoreServices/Applications")),
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

/// 一致の段。宣言順に比べるので、どの誤字の一致も正しい一致より下になる。
enum Match: Comparable {
  case typo(Int)
  case exact(Int)
}

/// 表示名とファイル名の良いほうのスコアで、query が app に一致するかを返す。
/// 部分列なら exact。そうでなく 1 文字を消すと部分列になるなら typo(置換・入れ替わり・余分の 1 文字)。
/// 1 文字の抜けはもともと部分列なので exact になる。
func match(query: String, app: AppEntry) -> Match? {
  func best(_ q: String) -> Int? {
    [app.name, app.fileName].compactMap { fuzzyScore(query: q, candidate: $0) }.max()
  }
  if let score = best(query) { return .exact(score) }
  // shortcut: 誤字は 3 文字以上で 1 文字だけ。2 文字の誤字を拾う要望が出たら置換の表を検討する
  guard query.count >= 3 else { return nil }
  return query.indices.compactMap { i in
    var variant = query
    variant.remove(at: i)
    return best(variant)
  }.max().map(Match.typo)
}

/// query が空なら名前順に全件を返す。空でなければ一致したものを、一致の良い順・名前の短い順・名前順で返す。
func rank(query: String, apps: [AppEntry]) -> [AppEntry] {
  let byName = { (a: AppEntry, b: AppEntry) in
    a.name.localizedStandardCompare(b.name) == .orderedAscending
  }
  if query.isEmpty { return apps.sorted(by: byName) }
  return apps.compactMap { app in match(query: query, app: app).map { (app, $0) } }
    .sorted { a, b in
      if a.1 != b.1 { return a.1 > b.1 }
      if a.0.name.count != b.0.name.count { return a.0.name.count < b.0.name.count }
      return byName(a.0, b.0)
    }
    .map(\.0)
}

/// 走査の結果と、結果が古くなったかを判定するためのディレクトリとその更新日時。
struct AppScan {
  let apps: [AppEntry]
  let watched: [(url: URL, date: Date?)]

  /// watched のどれにも項目の追加・削除が無ければ真。
  var isCurrent: Bool { watched.allSatisfy { modificationDate($0.url) == $0.date } }
}

/// 走査の結果を持ち、ディレクトリが変わったときだけ走査し直す。
struct AppCatalog {
  private let sources: [AppSource]
  private var scan: AppScan?

  init(sources: [AppSource]) { self.sources = sources }

  mutating func apps() -> [AppEntry] {
    if let scan, scan.isCurrent { return scan.apps }
    let start = ContinuousClock.now
    let scan = scanApplications(in: sources)
    let ms = Int((ContinuousClock.now - start) / .milliseconds(1))
    NSLog("LaunchpadLite: アプリを走査した(%ld 件、%ld ms)", scan.apps.count, ms)
    self.scan = scan
    return scan.apps
  }
}

// URL のリソース値はキャッシュされて変更を見落とすため、毎回 stat する。
private func modificationDate(_ url: URL) -> Date? {
  (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
}

/// メニューバー常駐(LSUIElement)・背景専用(LSBackgroundOnly)でなく、アイコンを持つなら真。
func isUserFacing(info: [String: Any]) -> Bool {
  // LSUIElement などは Bool の場合と文字列 "1" の場合がある。
  func flag(_ key: String) -> Bool {
    (info[key] as? NSNumber)?.boolValue ?? (info[key] as? NSString)?.boolValue ?? false
  }
  return !flag("LSUIElement") && !flag("LSBackgroundOnly")
    && (info["CFBundleIconFile"] != nil || info["CFBundleIconName"] != nil)
}

private func logUnreadable(_ url: URL, _ error: Error) {
  NSLog(
    "%@",
    "LaunchpadLite: ディレクトリを読めないので飛ばした path=\(url.path.debugDescription) error=\(String(describing: error).debugDescription)"
  )
}

/// sources を順に走査して .app を集める。.app の中は見ない。同じファイル名は先に見つかったほうを残す。
/// 存在しない根は飛ばし、読めないディレクトリはログに残して飛ばす。
func scanApplications(in sources: [AppSource]) -> AppScan {
  let fm = FileManager.default
  var seen = Set<String>()
  var apps: [AppEntry] = []
  var watched: [(url: URL, date: Date?)] = []
  // 日時はディレクトリを読む前に取る。読んでいる間に増えた項目は日時の食い違いとして次の判定で見つかる。
  func watch(_ url: URL) { watched.append((url, modificationDate(url))) }
  func add(_ url: URL) {
    let fileName = url.deletingPathExtension().lastPathComponent
    guard seen.insert(fileName).inserted else { return }
    // Finder で「すべての拡張子を表示」が有効だと displayName は「.app」付きで返る。
    // deletingPathExtension は「Foo 2.0」の「.0」も消すため、末尾の「.app」だけを外す。
    var name = fm.displayName(atPath: url.path)
    if name.hasSuffix(".app") { name.removeLast(4) }
    apps.append(AppEntry(name: name, fileName: fileName, url: url))
  }
  for source in sources {
    switch source {
    case .applications(let root):
      watch(root)
      guard fm.fileExists(atPath: root.path),
        let items = fm.enumerator(
          at: root, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
          options: .skipsPackageDescendants,
          errorHandler: { url, error in
            logUnreadable(url, error)
            return true
          })
      else { continue }
      for case let url as URL in items {
        if url.pathExtension == "app" {
          add(url)
        } else if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
          values.isDirectory == true, values.isPackage != true
        {
          // 列挙は前順なので、この時点では子をまだ読んでいない。
          watch(url)
        }
      }
    case .systemComponents(let root):
      watch(root)
      guard fm.fileExists(atPath: root.path) else { continue }
      let items: [URL]
      do {
        items = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
      } catch {
        logUnreadable(root, error)
        continue
      }
      for url in items where url.pathExtension == "app" {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        // Bundle(url:) はプロセス内でキャッシュされるため、Info.plist を直接読む。
        if let info = NSDictionary(contentsOf: plist) as? [String: Any], isUserFacing(info: info) {
          add(url)
        }
      }
    }
  }
  return AppScan(apps: apps, watched: watched)
}
