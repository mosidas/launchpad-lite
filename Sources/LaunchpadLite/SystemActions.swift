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

/// 画面をロックする。login.framework の非公開 API SACLockScreenImmediate を呼ぶ。
/// 公開 API に同等の手段が無いため、Hammerspoon の hs.caffeinate.lockScreen と同じ手段を使う。
func lockScreen() {
  guard
    let handle = dlopen(
      "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
    let symbol = dlsym(handle, "SACLockScreenImmediate")
  else {
    NSLog("SACLockScreenImmediate を取得できない")
    return
  }
  let lock = unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
  _ = lock()
}
