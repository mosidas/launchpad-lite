import Foundation
import IOKit.hidsystem

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
