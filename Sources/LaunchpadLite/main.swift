import AppKit
import Carbon.HIToolbox

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let launcher = LauncherPanel()
registerHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)) { launcher.toggle() }

app.run()
