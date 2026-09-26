import AppKit
import SwiftUI

/// ホットキーで開閉するランチャー。開くたびにアプリの一覧を取り直す。
final class LauncherPanel: NSPanel, NSWindowDelegate {
  private static let size = NSSize(width: 600, height: 360)

  init() {
    super.init(
      contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless],
      backing: .buffered, defer: false)
    level = .floating
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    delegate = self
  }

  override var canBecomeKey: Bool { true }

  func toggle() {
    if isVisible {
      orderOut(nil)
      return
    }
    // 新しいビューに差し替えて、入力と選択を空に戻す。
    contentView = NSHostingView(
      rootView: LauncherView(
        apps: scanApplications(in: applicationDirectories), size: Self.size,
        onLaunch: { [weak self] app in
          NSWorkspace.shared.openApplication(
            at: app.url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
          self?.orderOut(nil)
        },
        onClose: { [weak self] in self?.orderOut(nil) }))
    center()
    NSApp.activate()
    makeKeyAndOrderFront(nil)
  }

  func windowDidResignKey(_ notification: Notification) {
    orderOut(nil)
  }
}

private struct LauncherView: View {
  let apps: [AppEntry]
  let size: NSSize
  let onLaunch: (AppEntry) -> Void
  let onClose: () -> Void

  @State private var query = ""
  @State private var selection = 0
  @FocusState private var focused: Bool

  var body: some View {
    let results = Array(rank(query: query, apps: apps).prefix(8))
    VStack(alignment: .leading, spacing: 0) {
      TextField("アプリを検索", text: $query)
        .textFieldStyle(.plain)
        .font(.system(size: 24))
        .padding(16)
        .focused($focused)
        .onSubmit {
          if results.indices.contains(selection) { onLaunch(results[selection]) }
        }
        .onExitCommand(perform: onClose)
        .onKeyPress(.downArrow) {
          selection = min(selection + 1, results.count - 1)
          return .handled
        }
        .onKeyPress(.upArrow) {
          selection = max(selection - 1, 0)
          return .handled
        }
      ForEach(Array(results.enumerated()), id: \.element.url) { index, app in
        Text(app.name)
          .font(.system(size: 16))
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(index == selection ? Color.accentColor.opacity(0.3) : .clear)
      }
    }
    .frame(width: size.width, height: size.height, alignment: .top)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .onChange(of: query) { selection = 0 }
    .onAppear { focused = true }
  }
}
