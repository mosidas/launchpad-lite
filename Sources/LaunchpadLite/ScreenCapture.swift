import AppKit
import ImageIO

/// 撮った画像と、範囲選択で観測した矩形(CG 座標: 主画面の左上原点・y 下向き・ポイント)。
/// 矩形は画像の寸法と一致するときだけ入り、ウィンドウ単位の撮影や観測できなかったときは nil。
struct Capture {
  let image: CGImage
  let selection: CGRect?
}

enum CaptureError: Error {
  case launchFailed(any Error)
  case exitStatus(Int32)
  case unreadableImage
}

/// 範囲選択の押した位置と離した位置を囲む矩形。
func selectionRect(down: CGPoint, up: CGPoint) -> CGRect {
  CGRect(
    x: min(down.x, up.x), y: min(down.y, up.y), width: abs(up.x - down.x),
    height: abs(up.y - down.y))
}

/// selection が画像の寸法(ピクセル)と一致すれば selection を、しなければ nil を返す。
/// 実測では両端を含むため、画像は selection より 1pt ずつ大きい。差は 2pt まで許す。
func placement(selection: CGRect?, imagePixelSize: CGSize, scale: CGFloat) -> CGRect? {
  guard let selection, scale.isFinite, scale >= 1,
    abs(selection.width * scale - imagePixelSize.width) <= 2 * scale,
    abs(selection.height * scale - imagePixelSize.height) <= 2 * scale
  else { return nil }
  return selection
}

/// url の画像を読む。ファイルが無ければ(撮影の取り消し)nil。selection は placement で確かめて入れる。
func readCapture(from url: URL, selection: CGRect?, scale: CGFloat) throws -> Capture? {
  let data: Data
  do {
    data = try Data(contentsOf: url)
  } catch CocoaError.fileReadNoSuchFile {
    return nil
  } catch {
    throw CaptureError.unreadableImage
  }
  guard let source = CGImageSourceCreateWithData(data as CFData, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else { throw CaptureError.unreadableImage }
  let size = CGSize(width: image.width, height: image.height)
  return Capture(
    image: image, selection: placement(selection: selection, imagePixelSize: size, scale: scale))
}

/// 撮った画像を浮かべる矩形(Cocoa 座標)。selection があればその位置と大きさ、
/// 無ければ画像のポイント寸法で mouseLocation(Cocoa 座標)を中心に置く。
func floatingFrame(
  selection: CGRect?, imagePixelSize: CGSize, primaryScreenHeight: CGFloat,
  mouseLocation: CGPoint, backingScaleFactor: CGFloat
) -> CGRect {
  if let selection {
    return axFrame(fromCocoa: selection, primaryScreenHeight: primaryScreenHeight)
  }
  let width = imagePixelSize.width / backingScaleFactor
  let height = imagePixelSize.height / backingScaleFactor
  return CGRect(
    x: mouseLocation.x - width / 2, y: mouseLocation.y - height / 2, width: width, height: height)
}

/// screencapture で範囲を選ばせて撮る。取り消されたら nil。
/// screencapture は選んだ範囲を出力しない(stderr にも統合ログにも出ない。macOS 26.6 で実測)ので、
/// 撮影中だけ listen-only の tap で押した位置と離した位置を観測する。
@MainActor func captureInteractively() async throws -> Capture? {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "LaunchpadLite-capture-\(UUID().uuidString).png")
  defer { removeTemporaryFile(url) }

  let observer = SelectionObserver.start()
  if observer == nil {
    NSLog("%@", "LaunchpadLite: 範囲の観測なしで撮影する reason=tapUnavailable")
  }
  defer { observer?.stop() }

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
  process.arguments = ["-x", "-i", "-o", url.path]
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  let status: Int32 = try await withCheckedThrowingContinuation { continuation in
    process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
    do {
      try process.run()
    } catch {
      continuation.resume(throwing: CaptureError.launchFailed(error))
    }
  }
  guard status == 0 else { throw CaptureError.exitStatus(status) }

  let selection = observer?.selection
  guard
    let capture = try readCapture(
      from: url, selection: selection, scale: selection.map(backingScaleFactor) ?? 1)
  else {
    NSLog("%@", "LaunchpadLite: スクリーンショットを取り消した status=0")
    return nil
  }
  return capture
}

/// selection(CG 座標)の中心がある画面の倍率。どの画面にも無ければ 1。
@MainActor private func backingScaleFactor(of selection: CGRect) -> CGFloat {
  let rect = axFrame(fromCocoa: selection, primaryScreenHeight: primaryScreenHeight())
  let center = CGPoint(x: rect.midX, y: rect.midY)
  return NSScreen.screens.first { $0.frame.contains(center) }?.backingScaleFactor ?? 1
}

/// 撮影の一時ファイルを消す。無ければ何もしない。
private func removeTemporaryFile(_ url: URL) {
  do {
    try FileManager.default.removeItem(at: url)
  } catch CocoaError.fileNoSuchFile {
  } catch {
    let error = error as NSError
    NSLog(
      "%@", "LaunchpadLite: 撮影の一時ファイルを消せなかった error=\(error.domain)/\(error.code)")
  }
}

/// 範囲選択の最後の押下と離しの位置を、listen-only の tap で記録する。
@MainActor private final class SelectionObserver {
  private var down: CGPoint?
  private var up: CGPoint?
  private var tap: CFMachPort?
  private var source: CFRunLoopSource?

  /// 押下と離しの両方を観測していれば、それを囲む矩形(CG 座標)。
  var selection: CGRect? {
    guard let down, let up else { return nil }
    return selectionRect(down: down, up: up)
  }

  /// tap をメインの run loop に載せて観測を始める。tap を作れなければ(アクセシビリティ未許可)nil。
  static func start() -> SelectionObserver? {
    let observer = SelectionObserver()
    let types: [CGEventType] = [.leftMouseDown, .leftMouseUp]
    let mask = types.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
        eventsOfInterest: mask,
        callback: { _, type, event, userInfo in
          if let userInfo {
            let location = event.location
            MainActor.assumeIsolated {
              Unmanaged<SelectionObserver>.fromOpaque(userInfo).takeUnretainedValue()
                .record(type, at: location)
            }
          }
          return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(observer).toOpaque())
    else { return nil }
    let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    observer.tap = tap
    observer.source = source
    return observer
  }

  /// tap を外す。外した後は記録が変わらない。
  func stop() {
    if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    if let tap { CFMachPortInvalidate(tap) }
    source = nil
    tap = nil
  }

  private func record(_ type: CGEventType, at location: CGPoint) {
    switch type {
    case .leftMouseDown:
      down = location
      up = nil
    case .leftMouseUp:
      up = location
    default:
      break
    }
  }
}
