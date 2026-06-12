#!/bin/bash
# Package EnvSwitch into an installable .app bundle and a .dmg disk image.
# Works without Xcode (Command Line Tools only). Apple Silicon / macOS 14+.
set -euo pipefail

APP_NAME="EnvSwitch"
BUNDLE_ID="com.envswitch.app"
VERSION="0.2.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RELEASE_DIR=".build/release"
DIST="dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "==> Building release binaries"
swift build -c release

if [ ! -x "$RELEASE_DIR/EnvSwitchGUI" ] || [ ! -x "$RELEASE_DIR/envswitch" ]; then
  echo "error: release binaries not found in $RELEASE_DIR" >&2
  exit 1
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# GUI binary becomes the bundle's main executable. The CLI is embedded under
# Resources/ (NOT MacOS/) because macOS volumes are case-insensitive by default:
# "MacOS/EnvSwitch" and "MacOS/envswitch" would collide into one file.
cp "$RELEASE_DIR/EnvSwitchGUI" "$CONTENTS/MacOS/$APP_NAME"
cp "$RELEASE_DIR/envswitch" "$CONTENTS/Resources/envswitch"
chmod +x "$CONTENTS/MacOS/$APP_NAME" "$CONTENTS/Resources/envswitch"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP" || true

echo "==> Building DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo ""
echo "Done."
echo "  App:  $ROOT/$APP"
echo "  DMG:  $ROOT/$DMG"
