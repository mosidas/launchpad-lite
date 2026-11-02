import AppKit
import SwiftUI

/// ホットキーで開閉するランチャー。アプリの一覧は起動時に走査し、開いたときに置き場所のディレクトリが
/// 変わっていれば走査し直す。
final class LauncherPanel: NSPanel, NSWindowDelegate {
  private static let size = NSSize(width: 600, height: 360)
  /// 開く前に前面だったアプリ。閉じたときに前面へ戻す。
  private var previousApp: NSRunningApplication?
  private var catalog = AppCatalog(sources: appSources)

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
    _ = catalog.apps()
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
        apps: catalog.apps(), history: currentLaunchHistory, size: Self.size,
        onLaunch: { [weak self] app in
          Task { @MainActor in await launch(app) }
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

/// app を起動し、成功したときだけ履歴に残す。失敗したらログとアラートを出す。
@MainActor private func launch(_ app: AppEntry) async {
  do {
    _ = try await NSWorkspace.shared.openApplication(
      at: app.url, configuration: NSWorkspace.OpenConfiguration())
  } catch let error as CocoaError where error.code == .userCancelled {
    // 利用者が OS のダイアログ(初回起動の確認など)で取り消した。
    return
  } catch {
    let nsError = error as NSError
    NSLog(
      "%@",
      "LaunchpadLite: アプリを起動できなかった(\(app.fileName.debugDescription)、\(nsError.domain) \(nsError.code))"
    )
    NSApp.activate()
    let alert = NSAlert()
    alert.messageText = "「\(app.name)」を開けませんでした"
    alert.informativeText = "アプリが移動または削除されていないかを確かめて、もう一度お試しください。"
    alert.addButton(withTitle: "OK")
    alert.runModal()
    return
  }
  currentLaunchHistory.recordLaunch(of: app.url, at: .now)
  saveLaunchHistory(currentLaunchHistory)
}

private struct LauncherView: View {
  let apps: [AppEntry]
  let history: LaunchHistory
  let size: NSSize
  let onLaunch: (AppEntry) -> Void
  let onClose: () -> Void

  @State private var query = ""
  @State private var selection = 0
  @FocusState private var focused: Bool

  var body: some View {
    let results = Array(rank(query: query, apps: apps, history: history, now: .now).prefix(8))
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
        HStack(spacing: 8) {
          // IconServices がシステム全体でキャッシュするので自前では持たない(実測で 2 回目以降は 231 件で 16 ms)。
          Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
            .resizable()
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
          Text(app.name)
            .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
