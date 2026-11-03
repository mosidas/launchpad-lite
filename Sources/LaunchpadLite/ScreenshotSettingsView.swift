import SwiftUI

/// スクリーンショットの設定。変えるとその場で保存し、適用する。
struct ScreenshotSettingsView: View {
  @State private var settings = loadScreenshotSettings()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Form {
        Section("浮かべた画像") {
          LabeledContent("移動中の不透明度") {
            HStack {
              Slider(value: $settings.movingOpacity, in: 0.1...1, step: 0.05).frame(width: 180)
              Text(settings.movingOpacity.formatted(.percent.precision(.fractionLength(0))))
                .monospacedDigit().frame(width: 40, alignment: .trailing)
            }
          }
          Picker("表示する Space", selection: $settings.spaceMode) {
            ForEach(SpaceMode.allCases, id: \.self) { Text($0.title).tag($0) }
          }
          .help("新しく浮かべる画像に効きます。浮かべた画像では右クリックのメニューで切り替えます。")
        }
      }
      Button("既定に戻す") {
        saveScreenshotSettings(nil)
        settings = loadScreenshotSettings()
      }
    }
    .padding(20)
    .fixedSize()
    .onChange(of: settings) {
      // 保存値と同じなら書かない。書くと、既定に戻した直後に既定の値が保存され、キーが残る。
      if settings != loadScreenshotSettings() { saveScreenshotSettings(settings) }
      currentScreenshotSettings = settings
    }
  }
}
