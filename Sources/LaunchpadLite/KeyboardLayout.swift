import Carbon.HIToolbox

/// 現在の ASCII 配列で keycode を文字へ変換する関数を返す。配列データが取れなければ nil を返す。
/// 変換は修飾キーなし・デッドキーなしで、キーボード種別は LMGetKbdType() に従う。
@MainActor private func currentLayoutTranslator() -> ((UInt16) -> String?)? {
  guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
    let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
  else { return nil }
  let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
  let keyboardType = UInt32(LMGetKbdType())
  return { code in
    data.withUnsafeBytes { raw -> String? in
      guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
        return nil
      }
      var deadKeyState: UInt32 = 0
      var length = 0
      var chars = [UniChar](repeating: 0, count: 4)
      let status = UCKeyTranslate(
        layout, code, UInt16(kUCKeyActionDown), 0, keyboardType,
        OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, chars.count, &length, &chars)
      guard status == noErr, length > 0 else { return nil }
      return String(utf16CodeUnits: chars, count: length)
    }
  }
}

/// 現在の ASCII 配列で、修飾キーなしに keyCode が出す文字を返す。
@MainActor func layoutCharacter(keyCode: UInt16) -> String? {
  currentLayoutTranslator()?(keyCode)
}

/// 現在の ASCII 配列で、修飾キーなしに `character` を出す keycode を返す。JIS などでは記号の位置が ANSI と異なる。
@MainActor func keyCode(for character: Character) -> UInt32? {
  guard let translate = currentLayoutTranslator() else { return nil }
  return (0..<128).first { translate($0) == String(character) }.map(UInt32.init)
}
