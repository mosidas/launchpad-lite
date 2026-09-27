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

/// キーボードのサービスすべてに、キーの置き換えを書く。停止中や置き換えが空なら空の配列を書いて解除する。
@MainActor func applyKeyRemaps(_ settings: KeyboardSettings) {
  let mapping = keyRemapsPaused ? [] : userKeyMapping(settings.remaps)
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
