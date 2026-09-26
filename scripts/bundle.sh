#!/bin/sh
# release ビルドを dist/LaunchpadLite.app にまとめ、アドホック署名する。
set -eu
cd "$(dirname "$0")/.."
swift build -c release
app=dist/LaunchpadLite.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/LaunchpadLite" "$app/Contents/MacOS/LaunchpadLite"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>io.github.mosidas.launchpad-lite</string>
  <key>CFBundleName</key>
  <string>LaunchpadLite</string>
  <key>CFBundleExecutable</key>
  <string>LaunchpadLite</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
