import AppKit
import Carbon.HIToolbox

/// 自分で送ったイベントの eventSourceUserData に付ける印。tap はこの印のイベントを素通しする。
let syntheticEventMark: Int64 = 0x4C50_4C54  // "LPLT"

/// ホイール 1 目盛りの縦の移動量を、元の大きさによらず lines 行にする。reverse なら向きを反転する。
func scrolledLines(_ deltaY: Int64, lines: Int, reverse: Bool) -> Int64 {
  let lines = deltaY.signum() * Int64(lines)
  return reverse ? -lines : lines
}

/// サムホイールの横の移動量を左右のトリガーにする。inverted(ナチュラルなスクロール)なら符号を戻してから判定する。
func thumbTrigger(deltaX: Int64, inverted: Bool) -> MouseTrigger? {
  let deltaX = inverted ? -deltaX : deltaX
  if deltaX == 0 { return nil }
  return deltaX > 0 ? .thumbLeft : .thumbRight
}

/// KeyCombo の Carbon の修飾キーを CGEvent のフラグにする。矢印キーには実キーと同じ Fn・テンキーのフラグを足す。
func keyEventFlags(_ combo: KeyCombo) -> CGEventFlags {
  let pairs: [(Int, CGEventFlags)] = [
    (cmdKey, .maskCommand), (shiftKey, .maskShift), (optionKey, .maskAlternate),
    (controlKey, .maskControl),
  ]
  var flags: CGEventFlags = []
  for (key, flag) in pairs where combo.modifiers & UInt32(key) != 0 { flags.insert(flag) }
  let arrows = [kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow]
  if arrows.contains(Int(combo.keyCode)) { flags.formUnion([.maskSecondaryFn, .maskNumericPad]) }
  return flags
}

/// メディアキー(NX_SYSDEFINED、subtype 8)の data1。
func mediaKeyData1(_ key: Int32, down: Bool) -> Int {
  (Int(key) << 16) | ((down ? 0xA : 0xB) << 8)
}

/// 戻る・進むを ⌘[ / ⌘] で送るアプリか。Apple 製アプリだけ。他はマウスのボタン 3・4 を送る。
func usesNavigationKeys(bundleID: String?) -> Bool {
  bundleID?.hasPrefix("com.apple.") ?? false
}

@MainActor private var mouseEventTap: CFMachPort?
@MainActor private var loggedTapFailure = false
/// 記録中に自分で tap を止めているか。止めている間は作り直さない。
@MainActor private var tapPausedForRecording = false

/// マウスのホイールとボタンのイベントを書き換える tap をメインの run loop に載せる。既に載せていれば何もしない。
@MainActor func startMouseEventTap() {
  guard mouseEventTap == nil else { return }
  let types: [CGEventType] = [.scrollWheel, .otherMouseDown, .otherMouseUp]
  let mask = types.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
  guard
    let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: mask,
      callback: { _, type, event, _ in
        // CGEvent は Sendable でないので、書き換えだけを main actor で行い、イベントは閉包の外で返す。
        let drop = MainActor.assumeIsolated { handleMouseEvent(type, event) }
        return drop ? nil : Unmanaged.passUnretained(event)
      }, userInfo: nil)
  else {
    if !loggedTapFailure {
      NSLog("LaunchpadLite: マウスのイベント tap を作れなかった(アクセシビリティ未許可)")
      loggedTapFailure = true
    }
    return
  }
  NSLog("LaunchpadLite: マウスのイベント tap を作った")
  mouseEventTap = tap
  // 記録中に許可されて作られた tap は、記録が終わるまで止めておく。
  if tapPausedForRecording { CGEvent.tapEnable(tap: tap, enable: false) }
  CFRunLoopAddSource(
    CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
}

/// tap を止める・動かす。
@MainActor func setMouseEventTapEnabled(_ enabled: Bool) {
  tapPausedForRecording = !enabled
  if let tap = mouseEventTap { CGEvent.tapEnable(tap: tap, enable: enabled) }
}

/// 許可の取り消しで OS に無効にされた tap を捨てて作り直す。tap が無ければ作る。
/// 取り消しでは .tapDisabledByUserInput が届かないので、呼び出し側が定期的に呼ぶ。
@MainActor func restartMouseEventTapIfDisabled() {
  if let tap = mouseEventTap, !tapPausedForRecording, !CGEvent.tapIsEnabled(tap: tap) {
    NSLog("LaunchpadLite: 無効になったマウスのイベント tap を作り直す")
    CFMachPortInvalidate(tap)  // run loop source もこれで run loop から外れる
    mouseEventTap = nil
  }
  startMouseEventTap()
}

/// 割り当てを実行するか、イベントをその場で書き換える。イベントを捨てるなら true を返す。
@MainActor private func handleMouseEvent(_ type: CGEventType, _ event: CGEvent) -> Bool {
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if let tap = mouseEventTap { CGEvent.tapEnable(tap: tap, enable: true) }
    return false
  }
  guard event.getIntegerValueField(.eventSourceUserData) != syntheticEventMark else { return false }
  let settings = currentMouseSettings

  if type == .otherMouseDown || type == .otherMouseUp {
    let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
    guard let action = settings.action(for: .button(button)) else { return false }
    if type == .otherMouseDown { Task { @MainActor in perform(action) } }
    return true
  }
  // ponytail: 連続でない(行単位の)スクロールをホイールとみなし、トラックパッドを除く。
  // Magic Mouse も連続イベントなのでトラックパッド扱いになり書き換わらない。
  // 要るなら IOHIDManager で直前に入力したデバイスを追って判別する形に引き上げる。
  guard type == .scrollWheel, event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
  else { return false }

  // ponytail: サムホイールは 1 イベントにつき 1 回実行するので、速く回すと連発する。
  // 問題になったら移動量を累積し、しきい値を超えたら 1 回実行する形に引き上げる。
  if let trigger = thumbTrigger(
    deltaX: event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
    inverted: NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? false),
    let action = settings.action(for: trigger)
  {
    Task { @MainActor in perform(action) }
    return true
  }

  let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
  if deltaY != 0 {
    // DeltaAxis1 だけを書くと、CoreGraphics が FixedPt・Point の値を行数から計算し直す。
    event.setIntegerValueField(
      .scrollWheelEventDeltaAxis1,
      value: scrolledLines(deltaY, lines: settings.scrollLines, reverse: settings.reverseVertical))
  }
  if settings.reverseHorizontal && event.getIntegerValueField(.scrollWheelEventDeltaAxis2) != 0 {
    let fields: [CGEventField] = [
      .scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2,
      .scrollWheelEventPointDeltaAxis2,
    ]
    let values = fields.map { event.getDoubleValueField($0) }
    for (field, value) in zip(fields, values) { event.setDoubleValueField(field, value: -value) }
  }
  return false
}
