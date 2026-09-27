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
