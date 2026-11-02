import Foundation
import Testing

@testable import LaunchpadLite

private func entries(_ pairs: [(name: String, fileName: String)]) -> [AppEntry] {
  pairs.map {
    AppEntry(
      name: $0.name, fileName: $0.fileName,
      url: URL(fileURLWithPath: "/Applications/\($0.fileName).app"))
  }
}

private func rankedNames(_ query: String, _ names: [String]) -> [String] {
  rank(query: query, apps: entries(names.map { ($0, $0) })).map(\.name)
}

private let japaneseApps = entries([
  ("システム設定", "System Settings"), ("Safari", "Safari"), ("計算機", "Calculator"),
])

@Test func nonSubsequenceIsNil() {
  #expect(fuzzyScore(query: "xyz", candidate: "Safari") == nil)
  #expect(fuzzyScore(query: "fas", candidate: "Safari") == nil)
}

@Test func caseInsensitive() {
  #expect(fuzzyScore(query: "SAF", candidate: "safari") != nil)
  #expect(fuzzyScore(query: "saf", candidate: "SAFARI") != nil)
}

@Test func safPutsSafariFirst() {
  #expect(
    rankedNames("saf", ["System Settings", "Font Book", "Safari", "Stickies"]).first == "Safari")
}

@Test func vscPrefersWordStarts() {
  #expect(
    rankedNames("vsc", ["Viscount", "Visual Studio Code"]) == ["Visual Studio Code", "Viscount"])
}

@Test func prefixMatchBeatsMiddleMatch() {
  #expect(rankedNames("term", ["Preterm", "Terminal"]) == ["Terminal", "Preterm"])
}

@Test func tieGoesToShorterName() {
  #expect(rankedNames("not", ["Notes Pro", "Notes"]) == ["Notes", "Notes Pro"])
}

@Test func localizedNameMatches() {
  let found = rank(query: "設定", apps: japaneseApps)
  #expect(found.map(\.fileName) == ["System Settings"])
  #expect(found.first?.name == "システム設定")
}

@Test func englishNameStillMatches() {
  #expect(rank(query: "sys", apps: japaneseApps).map(\.fileName) == ["System Settings"])
}

@Test func betterOfTwoNamesRanks() {
  // 「Terminal」はローカライズ名では中間で、英語名では先頭で一致する。「Xterm」はどちらでも中間で一致し、名前が短い
  let apps = entries([("xterm", "Xterm"), ("プレterm", "Terminal")])
  #expect(rank(query: "term", apps: apps).map(\.fileName) == ["Terminal", "Xterm"])
}

@Test func emptyQueryReturnsAllByName() {
  #expect(rankedNames("", ["Safari", "iMovie", "Calendar"]) == ["Calendar", "iMovie", "Safari"])
}

@Test func scanFindsNestedAppsButNotAppsInsideApps() throws {
  let fm = FileManager.default
  let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? fm.removeItem(at: root) }
  for path in ["A.app/Contents/Inner.app", "Utilities/B.app", "Foo 2.0.app", "Other", "C.txt"] {
    try fm.createDirectory(
      at: root.appendingPathComponent(path), withIntermediateDirectories: true)
  }
  // macOS 26 の /Applications/Safari.app と同じく、hidden フラグ付きの .app への symlink
  let target = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".app")
  defer { try? fm.removeItem(at: target) }
  try fm.createDirectory(at: target, withIntermediateDirectories: true)
  var link = root.appendingPathComponent("D.app")
  try fm.createSymbolicLink(at: link, withDestinationURL: target)
  var hidden = URLResourceValues()
  hidden.isHidden = true
  try link.setResourceValues(hidden)
  link.removeAllCachedResourceValues()
  try #require(link.resourceValues(forKeys: [.isHiddenKey]).isHidden == true)
  let apps = scanApplications(in: [
    .applications(root), .applications(root.appendingPathComponent("missing")),
  ]).apps
  #expect(apps.map(\.fileName).sorted() == ["A", "B", "D", "Foo 2.0"])
  #expect(apps.map(\.name).sorted() == ["A", "B", "D", "Foo 2.0"])
}

private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

private func makeTempDir() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

private func makeApp(_ path: String, in root: URL, info: [String: Any] = [:]) throws {
  let contents = root.appendingPathComponent(path).appendingPathComponent("Contents")
  try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
  try (info as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"))
}

private func setModificationDate(_ url: URL) throws {
  try FileManager.default.setAttributes([.modificationDate: fixedDate], ofItemAtPath: url.path)
}

@Test func systemComponentsKeepsOnlyUserFacingApps() throws {
  let root = try makeTempDir()
  defer { try? FileManager.default.removeItem(at: root) }
  try makeApp("Visible.app", in: root, info: ["CFBundleIconFile": "AppIcon"])
  try makeApp("Named.app", in: root, info: ["CFBundleIconName": "AppIcon"])
  try makeApp("Agent.app", in: root, info: ["LSUIElement": true, "CFBundleIconFile": "AppIcon"])
  try makeApp(
    "StringAgent.app", in: root, info: ["LSUIElement": "1", "CFBundleIconFile": "AppIcon"])
  try makeApp(
    "Daemon.app", in: root, info: ["LSBackgroundOnly": true, "CFBundleIconFile": "AppIcon"])
  try makeApp("NoIcon.app", in: root)
  try makeApp("Sub/Nested.app", in: root, info: ["CFBundleIconFile": "AppIcon"])
  let names = scanApplications(in: [.systemComponents(root)]).apps.map(\.fileName).sorted()
  #expect(names == ["Named", "Visible"])
}

@Test func catalogReusesScanUntilDirectoryChanges() throws {
  let root = try makeTempDir()
  defer { try? FileManager.default.removeItem(at: root) }
  try makeApp("A.app", in: root)
  try setModificationDate(root)
  var catalog = AppCatalog(sources: [.applications(root)])
  #expect(catalog.apps().map(\.fileName) == ["A"])
  try makeApp("B.app", in: root)
  try setModificationDate(root)
  #expect(catalog.apps().map(\.fileName) == ["A"], "更新日時が同じなら走査し直さない")
  try FileManager.default.setAttributes(
    [.modificationDate: Date(timeIntervalSince1970: 1_700_000_001)], ofItemAtPath: root.path)
  #expect(catalog.apps().map(\.fileName).sorted() == ["A", "B"], "更新日時が変われば走査し直す")
}

@Test func catalogSeesAppsAddedInSubdirectory() throws {
  let root = try makeTempDir()
  defer { try? FileManager.default.removeItem(at: root) }
  let utilities = root.appendingPathComponent("Utilities")
  try FileManager.default.createDirectory(at: utilities, withIntermediateDirectories: true)
  try setModificationDate(utilities)
  try setModificationDate(root)
  var catalog = AppCatalog(sources: [.applications(root)])
  #expect(catalog.apps().isEmpty)
  try makeApp("Utilities/C.app", in: root)
  #expect(catalog.apps().map(\.fileName) == ["C"])
}

@Test func catalogSeesMissingRootCreatedLater() throws {
  let parent = try makeTempDir()
  defer { try? FileManager.default.removeItem(at: parent) }
  let root = parent.appendingPathComponent("Applications")
  var catalog = AppCatalog(sources: [.applications(root)])
  #expect(catalog.apps().isEmpty)
  try makeApp("D.app", in: root)
  #expect(catalog.apps().map(\.fileName) == ["D"])
}

@Test func scanSkipsUnreadableDirectoryAndKeepsOtherSources() throws {
  let root = try makeTempDir()
  let other = try makeTempDir()
  let locked = root.appendingPathComponent("Locked")
  defer {
    try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.removeItem(at: other)
  }
  try makeApp("Locked/Hidden.app", in: root)
  try makeApp("A.app", in: root)
  try makeApp("E.app", in: other)
  try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
  let names = scanApplications(in: [.applications(root), .applications(other)]).apps
    .map(\.fileName).sorted()
  #expect(names == ["A", "E"])
}
