import AppKit

/// 外部コマンドを起動し、終了を待たずに戻る。
func run(_ path: String, _ args: [String]) {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: path)
  process.arguments = args
  try? process.run()
}

/// スクリーンショットのツールバーを開く(⌘⇧5 と同じ)。保存先や形式は OS の設定に従う。
func openScreenshotToolbar() {
  NSWorkspace.shared.openApplication(
    at: URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"),
    configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
}

func sleepNow() { run("/usr/bin/pmset", ["sleepnow"]) }
