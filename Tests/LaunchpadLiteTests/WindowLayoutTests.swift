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

// 原点がゼロでない副画面を想定する。刻みは横 100、縦 50。
private let screen = CGRect(x: 100, y: 50, width: 2400, height: 1200)

@Test func halvesSplitScreen() {
  let window = CGRect(x: 500, y: 300, width: 600, height: 400)
  #expect(
    targetFrame(.leftHalf, window: window, screen: screen)
      == CGRect(x: 100, y: 50, width: 1200, height: 1200))
  #expect(
    targetFrame(.rightHalf, window: window, screen: screen)
      == CGRect(x: 1300, y: 50, width: 1200, height: 1200))
  #expect(
    targetFrame(.topHalf, window: window, screen: screen)
      == CGRect(x: 100, y: 50, width: 2400, height: 600))
  #expect(
    targetFrame(.bottomHalf, window: window, screen: screen)
      == CGRect(x: 100, y: 650, width: 2400, height: 600))
}

@Test func maximizeFillsScreen() {
  let window = CGRect(x: 500, y: 300, width: 600, height: 400)
  #expect(targetFrame(.maximize, window: window, screen: screen) == screen)
}

@Test func centerKeepsSize() {
  let window = CGRect(x: 0, y: 0, width: 600, height: 400)
  #expect(
    targetFrame(.center, window: window, screen: screen)
      == CGRect(x: 1000, y: 450, width: 600, height: 400))
}

@Test func centerShrinksWindowLargerThanScreen() {
  let window = CGRect(x: 0, y: 0, width: 3000, height: 1500)
  #expect(targetFrame(.center, window: window, screen: screen) == screen)
}

@Test func widenKeepsCenter() {
  let window = CGRect(x: 1000, y: 400, width: 600, height: 400)
  #expect(
    targetFrame(.widen, window: window, screen: screen)
      == CGRect(x: 950, y: 400, width: 700, height: 400))
}

@Test func widenAtLeftEdgeGrowsRight() {
  let window = CGRect(x: 100, y: 400, width: 600, height: 400)
  #expect(
    targetFrame(.widen, window: window, screen: screen)
      == CGRect(x: 100, y: 400, width: 700, height: 400))
}

@Test func narrowStopsAtMinimum() {
  let window = CGRect(x: 1000, y: 400, width: 250, height: 400)
  #expect(
    targetFrame(.narrow, window: window, screen: screen)
      == CGRect(x: 1025, y: 400, width: 200, height: 400))
}

@Test func moveLeftStopsAtScreenEdge() {
  let window = CGRect(x: 150, y: 400, width: 600, height: 400)
  #expect(
    targetFrame(.moveLeft, window: window, screen: screen)
      == CGRect(x: 100, y: 400, width: 600, height: 400))
}
