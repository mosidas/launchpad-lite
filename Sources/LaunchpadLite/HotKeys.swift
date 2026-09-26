import Carbon.HIToolbox
import Foundation

@MainActor private var hotKeyActions: [UInt32: @MainActor () -> Void] = [:]

/// グローバルホットキーを登録する。keyCode は kVK_*、modifiers は cmdKey などの和。
@MainActor
func registerHotKey(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
  if hotKeyActions.isEmpty {
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, _ in
        var hotKeyID = EventHotKeyID()
        GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
          MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        MainActor.assumeIsolated { hotKeyActions[hotKeyID.id]?() }
        return noErr
      }, 1, &spec, nil, nil)
  }
  let id = UInt32(hotKeyActions.count + 1)
  hotKeyActions[id] = action
  var ref: EventHotKeyRef?
  let status = RegisterEventHotKey(
    keyCode, modifiers, EventHotKeyID(signature: OSType(0x4C50_4C54), id: id),
    GetApplicationEventTarget(), 0, &ref)
  if status != noErr { NSLog("ホットキーを登録できない(keyCode \(keyCode)、status \(status))") }
}
