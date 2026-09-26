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

// 原点がゼロでない副画面を想定する。
private let screen = CGRect(x: 100, y: 50, width: 2400, height: 1200)

@Test func halvesSplitScreen() {
  #expect(
    targetFrame(.leftHalf, screen: screen)
      == CGRect(x: 100, y: 50, width: 1200, height: 1200))
  #expect(
    targetFrame(.rightHalf, screen: screen)
      == CGRect(x: 1300, y: 50, width: 1200, height: 1200))
  #expect(
    targetFrame(.topHalf, screen: screen)
      == CGRect(x: 100, y: 50, width: 2400, height: 600))
  #expect(
    targetFrame(.bottomHalf, screen: screen)
      == CGRect(x: 100, y: 650, width: 2400, height: 600))
}

@Test func maximizeFillsScreen() {
  #expect(targetFrame(.maximize, screen: screen) == screen)
}

@Test func quartersSplitScreen() {
  #expect(
    targetFrame(.topLeft, screen: screen)
      == CGRect(x: 100, y: 50, width: 1200, height: 600))
  #expect(
    targetFrame(.topRight, screen: screen)
      == CGRect(x: 1300, y: 50, width: 1200, height: 600))
  #expect(
    targetFrame(.bottomLeft, screen: screen)
      == CGRect(x: 100, y: 650, width: 1200, height: 600))
  #expect(
    targetFrame(.bottomRight, screen: screen)
      == CGRect(x: 1300, y: 650, width: 1200, height: 600))
}

@Test func centerThreeQuartersCentersOnScreen() {
  #expect(
    targetFrame(.centerThreeQuarters, screen: screen)
      == CGRect(x: 400, y: 200, width: 1800, height: 900))
}

// 主画面 2000x1000 から、右隣で上に 200 ずれた 1000x800 の画面へ移す。
private let fromScreen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
private let toScreen = CGRect(x: 2000, y: -200, width: 1000, height: 800)

@Test func frameMovedKeepsRatio() {
  let window = CGRect(x: 500, y: 250, width: 800, height: 400)
  #expect(
    frameMoved(window: window, from: fromScreen, to: toScreen)
      == CGRect(x: 2250, y: 0, width: 400, height: 320))
}

@Test func frameMovedPushesBackInside() {
  let window = CGRect(x: 1800, y: 900, width: 600, height: 300)
  #expect(
    frameMoved(window: window, from: fromScreen, to: toScreen)
      == CGRect(x: 2700, y: 360, width: 300, height: 240))
}

@Test func frameMovedCapsSizeAtScreen() {
  let window = CGRect(x: -100, y: 0, width: 2400, height: 1200)
  #expect(frameMoved(window: window, from: fromScreen, to: toScreen) == toScreen)
}
