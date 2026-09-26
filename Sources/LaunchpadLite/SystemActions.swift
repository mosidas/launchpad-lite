import Foundation

/// 外部コマンドを起動し、終了を待たずに戻る。
func run(_ path: String, _ args: [String]) {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: path)
  process.arguments = args
  try? process.run()
}

/// 範囲を選択してスクリーンショットを撮り、クリップボードへ入れる。
func captureRegionToClipboard() { run("/usr/sbin/screencapture", ["-ic"]) }

func sleepNow() { run("/usr/bin/pmset", ["sleepnow"]) }
