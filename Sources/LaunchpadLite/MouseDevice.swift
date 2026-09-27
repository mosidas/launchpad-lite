import Foundation
import IOKit.hidsystem

// HID のサービスに設定を書く。マウスにはポインタの加速と速度、キーボードにはキーの置き換え(UserKeyMapping)を書く。

/// マウスのサービスに書く HID のプロパティ。加速の方式を切り替えてから速度(IOFixed)を書く。
func pointerProperties(_ settings: MouseSettings) -> [(key: String, value: Int)] {
  [
    ("HIDUseLinearScalingMouseAcceleration", settings.pointerAcceleration ? 0 : 1),
    ("HIDMouseAcceleration", Int((settings.pointerSpeed * 65536).rounded())),
  ]
}

// ponytail: 公開の IOHIDEventSystemClientCreateSimpleClient では HIDUseLinearScalingMouseAcceleration を
// 読み書きできない(書き込みが false を返す)ため、LinearMouse と同じ非公開の IOHIDEventSystemClientCreate を使う。
// 関数が消えたら Simple client に戻り、速度だけが効いて加速の設定は効かなくなる。
@MainActor private let hidClient: IOHIDEventSystemClient = {
  typealias Create = @convention(c) (CFAllocator?) -> Unmanaged<IOHIDEventSystemClient>?
  // RTLD_DEFAULT
  if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "IOHIDEventSystemClientCreate"),
    let client = unsafeBitCast(symbol, to: Create.self)(kCFAllocatorDefault)
  {
    return client.takeRetainedValue()
  }
  return IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
}()

@MainActor private var loggedWriteFailure = false

/// マウス(トラックパッドは除く)のサービスすべてに、ポインタの加速と速度を書く。
@MainActor func applyPointerSettings(_ settings: MouseSettings) {
  let services = IOHIDEventSystemClientCopyServices(hidClient) as? [IOHIDServiceClient] ?? []
  for service in services
  where IOHIDServiceClientCopyProperty(service, "HIDPointerAccelerationType" as CFString)
    as? String == "HIDMouseAcceleration"
  {
    for (key, value) in pointerProperties(settings) {
      let written = IOHIDServiceClientSetProperty(service, key as CFString, value as CFNumber)
      if !written && !loggedWriteFailure {
        loggedWriteFailure = true
        NSLog("LaunchpadLite: マウスの \(key) を書けなかった")
      }
    }
  }
}

@MainActor private var keyRemapsPaused = false
@MainActor private var loggedKeyMappingFailure = false
@MainActor private var loggedCapsLockFailure = false
// ponytail: 異常終了した回の置き換えは、次の起動で置き換えが空なら解除されない。問題になったら起動時に一度だけ空の配列を書く形に引き上げる。
/// 空でない置き換えを書いたか。書いていなければ空の配列も書かず、hidutil などで設定した置き換えを残す。
@MainActor private var wroteKeyMapping = false

/// キーボードのサービスすべてに、キーの置き換えを書く。停止中や置き換えが空なら、以前に書いた置き換えを空の配列で解除する。
@MainActor func applyKeyRemaps(_ settings: KeyboardSettings) {
  let mapping = keyRemapsPaused ? [] : userKeyMapping(settings.remaps)
  if mapping.isEmpty && !wroteKeyMapping { return }
  wroteKeyMapping = !mapping.isEmpty
  let services = IOHIDEventSystemClientCopyServices(hidClient) as? [IOHIDServiceClient] ?? []
  for service in services
  where IOHIDServiceClientConformsTo(
    service, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard)) != 0
  {
    let written = IOHIDServiceClientSetProperty(
      service, "UserKeyMapping" as CFString, mapping as CFArray)
    if !written && !loggedKeyMappingFailure {
      loggedKeyMappingFailure = true
      NSLog("LaunchpadLite: キーボードの UserKeyMapping を書けなかった")
    }
  }
}

/// キーの置き換えを止める・再開する。キーの記録中と終了時に止める。
@MainActor func setKeyRemapsEnabled(_ enabled: Bool) {
  keyRemapsPaused = !enabled
  applyKeyRemaps(currentKeyboardSettings)
}

/// Caps Lock のロックを点ける・消す。ロックは HID 層で切り替わるので、イベントを捨てても戻らない。
@MainActor func setCapsLockState(_ on: Bool) {
  var connect: io_connect_t = 0
  let service = IOServiceGetMatchingService(
    kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
  defer { IOObjectRelease(service) }
  var result = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
  if result == KERN_SUCCESS {
    result = IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), on)
    IOServiceClose(connect)
  }
  if result != KERN_SUCCESS && !loggedCapsLockFailure {
    loggedCapsLockFailure = true
    NSLog("LaunchpadLite: Caps Lock のロックを切り替えられなかった(\(result))")
  }
}
