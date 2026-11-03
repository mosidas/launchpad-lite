import Testing

@testable import LaunchpadLite

@Test @MainActor func settingsPageTitlesAreUnique() {
  #expect(Set(settingsPages.map(\.id)).count == settingsPages.count)
}
