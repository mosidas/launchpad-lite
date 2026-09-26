import Foundation
import Testing

@testable import LaunchpadLite

private func entries(_ names: [String]) -> [AppEntry] {
  names.map { AppEntry(name: $0, url: URL(fileURLWithPath: "/Applications/\($0).app")) }
}

private func rankedNames(_ query: String, _ names: [String]) -> [String] {
  rank(query: query, apps: entries(names)).map(\.name)
}

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

@Test func emptyQueryReturnsAllByName() {
  #expect(rankedNames("", ["Safari", "iMovie", "Calendar"]) == ["Calendar", "iMovie", "Safari"])
}

@Test func scanFindsNestedAppsButNotAppsInsideApps() throws {
  let fm = FileManager.default
  let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? fm.removeItem(at: root) }
  for path in ["A.app/Contents/Inner.app", "Utilities/B.app", "Other", "C.txt"] {
    try fm.createDirectory(
      at: root.appendingPathComponent(path), withIntermediateDirectories: true)
  }
  let names = scanApplications(in: [root, root.appendingPathComponent("missing")]).map(\.name)
  #expect(names.sorted() == ["A", "B"])
}
