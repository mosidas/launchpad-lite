import CoreGraphics
import Foundation

/// 自分で送ったイベントの eventSourceUserData に付ける印。tap はこの印のイベントを素通しする。
let syntheticEventMark: Int64 = 0x4C50_4C54  // "LPLT"

/// ホイール 1 目盛りの縦の移動量を、元の大きさによらず lines 行にする。reverse なら向きを反転する。
func scrolledLines(_ deltaY: Int64, lines: Int, reverse: Bool) -> Int64 {
  let lines = deltaY.signum() * Int64(lines)
  return reverse ? -lines : lines
}

@MainActor private var mouseEventTap: CFMachPort?

/// マウスのホイールとボタンのイベントを書き換える tap をメインの run loop に載せる。
@MainActor func startMouseEventTap() {
  let types: [CGEventType] = [.scrollWheel, .otherMouseDown, .otherMouseUp]
  let mask = types.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
  guard
    let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: mask,
      callback: { _, type, event, _ in
        // CGEvent は Sendable でないので、書き換えだけを main actor で行い、イベントは閉包の外で返す。
        MainActor.assumeIsolated { handleMouseEvent(type, event) }
        return Unmanaged.passUnretained(event)
      }, userInfo: nil)
  else {
    NSLog("LaunchpadLite: マウスのイベント tap を作れなかった(アクセシビリティ未許可)")
    return
  }
  mouseEventTap = tap
  CFRunLoopAddSource(
    CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
}

/// tap を止める・動かす。
@MainActor func setMouseEventTapEnabled(_ enabled: Bool) {
  if let tap = mouseEventTap { CGEvent.tapEnable(tap: tap, enable: enabled) }
}

/// イベントをその場で書き換える。
@MainActor private func handleMouseEvent(_ type: CGEventType, _ event: CGEvent) {
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if let tap = mouseEventTap { CGEvent.tapEnable(tap: tap, enable: true) }
    return
  }
  // ponytail: 連続でない(行単位の)スクロールをホイールとみなし、トラックパッドを除く。
  // Magic Mouse も連続イベントなのでトラックパッド扱いになり書き換わらない。
  // 要るなら IOHIDManager で直前に入力したデバイスを追って判別する形に引き上げる。
  guard event.getIntegerValueField(.eventSourceUserData) != syntheticEventMark,
    type == .scrollWheel, event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
  else { return }

  let settings = currentMouseSettings
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
}
