#!/bin/sh
# release ビルドを dist/LaunchpadLite.app にまとめ、アドホック署名する。
set -eu
cd "$(dirname "$0")/.."
swift build -c release
app=dist/LaunchpadLite.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/LaunchpadLite" "$app/Contents/MacOS/LaunchpadLite"

# Resources/AppIcon.png から AppIcon.icns を作る。
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
swift scripts/icon.swift frame Resources/AppIcon.png "$tmp/icon-1024.png"
iconset="$tmp/AppIcon.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$tmp/icon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$tmp/icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
mkdir -p "$app/Contents/Resources"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>io.github.mosidas.launchpad-lite</string>
  <key>CFBundleName</key>
  <string>LaunchpadLite</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
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
