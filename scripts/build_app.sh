#!/usr/bin/env bash
# Compila y empaqueta ConectorXiaomi.app (ejecutar en macOS 14+ con Xcode/Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/ConectorXiaomi"
APP="build/ConectorXiaomi.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ConectorXiaomi"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Conector Xiaomi</string>
  <key>CFBundleIdentifier</key><string>com.davigoca.conectorxiaomi</string>
  <key>CFBundleExecutable</key><string>ConectorXiaomi</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "Listo: $APP  (abre con: open $APP)"
