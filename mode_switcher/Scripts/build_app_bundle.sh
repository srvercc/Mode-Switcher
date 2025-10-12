#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ModeSwitcher"
APP_BUNDLE="$APP_NAME.app"
PRODUCT_NAME="ModeSwitcherApp"
PRODUCT_PATH=".build/release/$PRODUCT_NAME"
RESOURCE_BUNDLE=".build/release/MASShortcut_MASShortcut.bundle"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
ICON_SOURCE="Assets/AppIcon.icns"

if [[ ! -f "$PRODUCT_PATH" ]]; then
  echo "Release binary not found at $PRODUCT_PATH. Run 'swift build -c release' first." >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cat <<'PLIST' >"$INFO_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.example.modeswitcher</string>
  <key>CFBundleExecutable</key>
  <string>ModeSwitcherApp</string>
  <key>CFBundleName</key>
  <string>ModeSwitcher</string>
  <key>CFBundleDisplayName</key>
  <string>Mode Switcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

cp "$PRODUCT_PATH" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "Created $APP_BUNDLE"
