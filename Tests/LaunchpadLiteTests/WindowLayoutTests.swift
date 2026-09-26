import CoreGraphics
import Testing

@testable import LaunchpadLite

@Test func axFrameOnPrimaryScreen() {
  let rect = CGRect(x: 100, y: 200, width: 300, height: 400)
  #expect(
    axFrame(fromCocoa: rect, primaryScreenHeight: 1000)
      == CGRect(x: 100, y: 400, width: 300, height: 400))
}

@Test func axFrameOnSecondaryScreenAbovePrimary() {
  let rect = CGRect(x: 0, y: 1000, width: 1920, height: 1080)
  #expect(
    axFrame(fromCocoa: rect, primaryScreenHeight: 1000)
      == CGRect(x: 0, y: -1080, width: 1920, height: 1080))
}
