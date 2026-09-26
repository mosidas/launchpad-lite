import AppKit
import SwiftUI

/// ホットキーで開閉するランチャー。開くたびにアプリの一覧を取り直す。
final class LauncherPanel: NSPanel, NSWindowDelegate {
  private static let size = NSSize(width: 600, height: 360)
  /// 開く前に前面だったアプリ。閉じたときに前面へ戻す。
  private var previousApp: NSRunningApplication?

  init() {
    super.init(
      contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless],
      backing: .buffered, defer: false)
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    delegate = self
  }

  override var canBecomeKey: Bool { true }

  func toggle() {
    if isVisible {
      close(restoringFocus: true)
      return
    }
    // 新しいビューに差し替えて、入力と選択を空に戻す。
    contentView = NSHostingView(
      rootView: LauncherView(
        apps: scanApplications(in: applicationDirectories), size: Self.size,
        onLaunch: { [weak self] app in
          NSWorkspace.shared.openApplication(
            at: app.url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
          // 起動したアプリが前面になるので、元のアプリは戻さない。
          self?.close(restoringFocus: false)
        },
        onClose: { [weak self] in self?.close(restoringFocus: true) }))
    center()
    previousApp = NSWorkspace.shared.frontmostApplication
    NSApp.activate()
    makeKeyAndOrderFront(nil)
  }

  /// 他のアプリへ移ってキーを失ったときは、移った先を上書きしないよう元のアプリを戻さない。
  func windowDidResignKey(_ notification: Notification) {
    close(restoringFocus: false)
  }

  /// すべての閉じる経路が通る。前面を元のアプリへ返し、返せなければ自アプリを隠す。
  private func close(restoringFocus: Bool) {
    guard isVisible else { return }
    let previous = previousApp
    previousApp = nil
    orderOut(nil)
    if restoringFocus, let previous, !previous.isTerminated {
      previous.activate()
    } else {
      NSApp.hide(nil)
    }
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
