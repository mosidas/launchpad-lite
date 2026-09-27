// アプリアイコンの元絵を macOS のアイコンの枠に収める。swift scripts/icon.swift frame <in.png> <out.png> で実行する。
//   入力を 824×824 に拡縮し、1024×1024 の透明なキャンバスの中央に置く(周囲 100px を空ける)。
import AppKit

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 3, args[0] == "frame" else { fail("使い方: icon.swift frame <in.png> <out.png>") }
guard let image = NSImage(contentsOfFile: args[1]) else { fail("読めない: \(args[1])") }
guard
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)
else { fail("ビットマップを作れない") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
image.draw(in: NSRect(x: 100, y: 100, width: 824, height: 824))
NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else { fail("PNG にできない") }
do { try data.write(to: URL(fileURLWithPath: args[2])) } catch { fail("\(args[2]): \(error)") }
