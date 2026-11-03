import AppKit
import Testing

@testable import LaunchpadLite

@Test func commandRequiresCommandKeyForLetters() {
  #expect(FloatingCommand(characters: "c", modifiers: .command) == .copy)
  #expect(FloatingCommand(characters: "s", modifiers: .command) == .save)
  #expect(FloatingCommand(characters: "w", modifiers: .command) == .close)
  #expect(FloatingCommand(characters: "c", modifiers: []) == nil)
  #expect(FloatingCommand(characters: "x", modifiers: .command) == nil)
  #expect(FloatingCommand(characters: "c", modifiers: [.command, .option]) == nil)
  #expect(FloatingCommand(characters: "w", modifiers: [.command, .control]) == nil)
}

@Test func commandZoomsWithPlusEqualsSemicolonAndMinus() {
  #expect(FloatingCommand(characters: "+", modifiers: [.command, .shift]) == .zoomIn)
  #expect(FloatingCommand(characters: "=", modifiers: .command) == .zoomIn)
  #expect(FloatingCommand(characters: ";", modifiers: .command) == .zoomIn)
  #expect(FloatingCommand(characters: "-", modifiers: .command) == .zoomOut)
  #expect(FloatingCommand(characters: "0", modifiers: .command) == .resetFrame)
}

@Test func escapeClosesWithoutModifiers() {
  #expect(FloatingCommand(characters: "\u{1b}", modifiers: []) == .close)
  #expect(FloatingCommand(characters: "\u{1b}", modifiers: .command) == nil)
}

@Test func zoomLevelStopsAt250And25Percent() {
  let zoomedIn = (0..<7).reduce(0) { level, _ in clampedZoomLevel(level, step: 1) }
  #expect(zoomedIn == 6)
  let zoomedOut = (0..<4).reduce(0) { level, _ in clampedZoomLevel(level, step: -1) }
  #expect(zoomedOut == -3)
}

@Test func scrollChangesOpacityWithinTenToHundredPercent() {
  #expect(abs(scrolledOpacity(1, deltaY: -20) - 0.9) < 1e-9)
  #expect(scrolledOpacity(1, deltaY: 20) == 1)
  #expect(scrolledOpacity(0.2, deltaY: -100) == 0.1)
}

@Test func scaledFrameKeepsCenter() {
  let original = CGRect(x: 100, y: 100, width: 200, height: 100)
  #expect(zoomedFrame(original, level: 0) == original)
  #expect(zoomedFrame(original, level: 2) == CGRect(x: 50, y: 75, width: 300, height: 150))
  #expect(zoomedFrame(original, level: -2) == CGRect(x: 150, y: 125, width: 100, height: 50))
}
