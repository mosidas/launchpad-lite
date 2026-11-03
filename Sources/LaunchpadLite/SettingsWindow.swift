import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor var settingsWindow: NSWindow?

/// 設定ウィンドウのサイドバーに並ぶ 1 ページ。題名を選択の識別に使うので、題名は一意にする。
struct SettingsPage: Identifiable {
  let title: String
  let systemImage: String
  let content: @MainActor () -> AnyView
  var id: String { title }

  init<Content: View>(
    _ title: String, systemImage: String,
    @ViewBuilder content: @escaping @MainActor () -> Content
  ) {
    self.title = title
    self.systemImage = systemImage
    self.content = { AnyView(content()) }
  }
}

/// 設定のページの一覧。サイドバーにこの順で並ぶ。ページはこの一覧へ 1 要素を足して加える。
@MainActor let settingsPages: [SettingsPage] = [
  SettingsPage("ホットキー", systemImage: "command") { HotKeySettingsView() },
  SettingsPage("マウス", systemImage: "computermouse") { MouseSettingsView() },
  SettingsPage("キーボード", systemImage: "keyboard") { KeyboardSettingsView() },
]

/// 設定ウィンドウを開く。ウィンドウは 1 つだけ作って使い回す。
@MainActor
func showSettings() {
  let window =
    settingsWindow
    ?? {
      let window = NSWindow(
        contentRect: .zero, styleMask: [.titled, .closable, .resizable], backing: .buffered,
        defer: false)
      window.title = "LaunchpadLite の設定"
      window.isReleasedWhenClosed = false
      window.setContentSize(NSSize(width: 760, height: 560))
      settingsWindow = window
      return window
    }()
  // 開くたびにビューを作り直し、保存値を読み直す。
  // 内容の大きさにウィンドウを合わせると、ページを切り替えるたびにウィンドウの大きさが変わるため、最小の大きさだけを伝える。
  // どのページも初期の幅に収まるので(注記は SettingsNote で折り返す)、最小の大きさがウィンドウを広げることはない。
  let hosting = NSHostingView(rootView: SettingsRootView())
  hosting.sizingOptions = [.minSize]
  window.contentView = hosting
  window.center()
  NSApp.activate()
  window.makeKeyAndOrderFront(nil)
}

/// サイドバーでページを選び、右側に選んだページを出す。
private struct SettingsRootView: View {
  @State private var selection: SettingsPage.ID? = settingsPages[0].id

  var body: some View {
    NavigationSplitView(columnVisibility: .constant(.all)) {
      List(settingsPages, selection: $selection) { Label($0.title, systemImage: $0.systemImage) }
        // ⌘クリックで選択を外されたら、最後に選んでいたページを選び直す。
        // Binding の set で nil を捨てるだけでは、状態が変わらずサイドバーの選択の表示が消えたままになる。
        .onChange(of: selection) { old, new in if new == nil { selection = old } }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        .toolbar(removing: .sidebarToggle)
    } detail: {
      let page = settingsPages.first { $0.id == selection } ?? settingsPages[0]
      // 同じ型のビューのページどうしでも、切り替えで状態を作り直し、.onDisappear を呼ぶ。
      ScrollView { page.content().id(page.id) }
    }
  }
}

/// ページの下に置く注記。長い文でもページの幅を広げないよう、決まった幅で折り返す。
/// 幅を上限(maxWidth)にすると、高さが 1 行分で決まり、折り返した行が下の要素に重なる。
struct SettingsNote: View {
  let text: String

  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text).font(.caption).foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .frame(width: 360, alignment: .leading)
  }
}

/// ホットキーの一覧。行を押してキーを押すと記録し、その場で登録し直す。
private struct HotKeySettingsView: View {
  @State private var combos = Dictionary(
    uniqueKeysWithValues: HotKeyAction.allCases.map { ($0, loadKeyCombo($0)) })
  @State private var recording: HotKeyAction?
  @State private var failed = Set<HotKeyAction>()
  @State private var monitor: Any?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Grid(alignment: .leading, verticalSpacing: 6) {
        ForEach(HotKeyAction.allCases, id: \.self) { action in
          GridRow {
            Text(action.title)
            Button(recording == action ? "キーを入力…" : combos[action]?.label ?? "") {
              startRecording(action)
            }
            .frame(minWidth: 120)
            if failed.contains(action) {
              Text("登録できない").foregroundStyle(.red)
            }
          }
        }
      }
      SettingsNote("⌘・⌃・⌥ のいずれかを含むキーを受け付ける。Escape で取り消す。")
      Button("既定に戻す") {
        stopRecording()
        for action in HotKeyAction.allCases { saveKeyCombo(nil, for: action) }
        combos = Dictionary(
          uniqueKeysWithValues: HotKeyAction.allCases.map { ($0, loadKeyCombo($0)) })
        failed = Set(registerAllHotKeys())
      }
    }
    .padding(20)
    .fixedSize()
    // 閉じても、他のアプリへ切り替えても、ホットキーが外れたままにならないよう記録を終える。
    // 閉じるボタンでは .onDisappear が呼ばれないので、ウィンドウの通知も受ける。
    .onDisappear { stopRecording() }
    .onReceive(
      NotificationCenter.default.publisher(
        for: NSWindow.willCloseNotification, object: settingsWindow)
    ) { _ in stopRecording() }
    .onReceive(
      NotificationCenter.default.publisher(
        for: NSWindow.didResignKeyNotification, object: settingsWindow)
    ) { _ in stopRecording() }
  }

  /// 記録中は全ホットキーとマウスの tap を止める。止めないと、記録しようとしたキーや、
  /// ショートカットを割り当てたマウスボタンの送出するキーで、動作が先に起きる。
  private func startRecording(_ action: HotKeyAction) {
    stopRecording()
    setMouseEventTapEnabled(false)
    unregisterAllHotKeys()
    recording = action
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let modifiers = carbonModifiers(event.modifierFlags)
      if event.keyCode == kVK_Escape && modifiers == 0 {
        stopRecording()
      } else if modifiers & UInt32(cmdKey | controlKey | optionKey) != 0 {
        // ⌘⌃⌥ のどれも含まないキーは、文字入力を奪うので受け付けない。
        let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        saveKeyCombo(combo, for: action)
        combos[action] = combo
        stopRecording()
      }
      return nil
    }
  }

  private func stopRecording() {
    guard let monitor else { return }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
    recording = nil
    setMouseEventTapEnabled(true)
    failed = Set(registerAllHotKeys())
  }
}
