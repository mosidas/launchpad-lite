import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import LaunchpadLite

@Test func zeroDeltaStaysZero() {
  #expect(scrolledLines(0, lines: 4, reverse: false) == 0)
  #expect(scrolledLines(0, lines: 4, reverse: true) == 0)
}

@Test func anyPositiveDeltaBecomesLineCount() {
  #expect(scrolledLines(1, lines: 4, reverse: false) == 4)
  #expect(scrolledLines(3, lines: 4, reverse: false) == 4)
}

@Test func negativeDeltaBecomesNegativeLineCount() {
  #expect(scrolledLines(-2, lines: 4, reverse: false) == -4)
}

@Test func reverseFlipsSign() {
  #expect(scrolledLines(1, lines: 4, reverse: true) == -4)
  #expect(scrolledLines(-2, lines: 4, reverse: true) == 4)
}

@Test func oneLinePerNotch() {
  #expect(scrolledLines(3, lines: 1, reverse: false) == 1)
  #expect(scrolledLines(-3, lines: 1, reverse: false) == -1)
}

@Test func zeroThumbDeltaHasNoTrigger() {
  #expect(thumbTrigger(deltaX: 0, inverted: false) == nil)
  #expect(thumbTrigger(deltaX: 0, inverted: true) == nil)
}

@Test func thumbSignAndInversionPickSide() {
  #expect(thumbTrigger(deltaX: 1, inverted: false) == .thumbLeft)
  #expect(thumbTrigger(deltaX: -1, inverted: false) == .thumbRight)
  #expect(thumbTrigger(deltaX: 1, inverted: true) == .thumbRight)
  #expect(thumbTrigger(deltaX: -1, inverted: true) == .thumbLeft)
}

@Test func modifiersMapToEventFlags() {
  let all = UInt32(cmdKey | shiftKey | optionKey | controlKey)
  #expect(
    keyEventFlags(KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: all))
      == [.maskCommand, .maskShift, .maskAlternate, .maskControl])
  #expect(
    keyEventFlags(KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey))) == .maskCommand)
  #expect(keyEventFlags(KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: 0)) == [])
}

@Test func arrowKeysGetFnAndNumericPadFlags() {
  for key in [kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow] {
    #expect(
      keyEventFlags(KeyCombo(keyCode: UInt32(key), modifiers: UInt32(controlKey)))
        == [.maskControl, .maskSecondaryFn, .maskNumericPad])
  }
}

@Test func mediaKeyDataEncodesKeyAndState() {
  #expect(mediaKeyData1(0, down: true) == 0x0A00)
  #expect(mediaKeyData1(0, down: false) == 0x0B00)
  #expect(mediaKeyData1(16, down: true) == 0x10_0A00)
  #expect(mediaKeyData1(7, down: false) == 0x7_0B00)
}

@Test func onlyAppleAppsUseNavigationKeys() {
  #expect(usesNavigationKeys(bundleID: "com.apple.Safari"))
  #expect(!usesNavigationKeys(bundleID: "com.microsoft.VSCode"))
  #expect(!usesNavigationKeys(bundleID: nil))
}
