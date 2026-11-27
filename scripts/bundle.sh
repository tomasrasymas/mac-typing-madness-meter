#!/bin/sh
# Build a release binary and wrap it in build/Typing Madness.app.
#
# A real app bundle lets macOS credit Input Monitoring to "Typing Madness"
# itself instead of the terminal you launched it from. The bundle is ad-hoc
# signed, so macOS may ask for the permission again after each rebuild.
#
# UNIVERSAL=1 builds for both Apple Silicon and Intel (used for releases).
# VERSION=x.y.z sets the version shown in Finder.
set -eu

cd "$(dirname "$0")/.."
APP="build/Typing Madness.app"
BUNDLE_ID="${BUNDLE_ID:-dev.typingmadness.app}"
VERSION="${VERSION:-0.1.0}"

ARCH_FLAGS=""
if [ "${UNIVERSAL:-0}" = 1 ]; then ARCH_FLAGS="--arch arm64 --arch x86_64"; fi

# shellcheck disable=SC2086 # ARCH_FLAGS is meant to split into words
swift build -c release --product TypingMadness $ARCH_FLAGS
# shellcheck disable=SC2086
BIN="$(swift build -c release --product TypingMadness $ARCH_FLAGS --show-bin-path)/TypingMadness"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TypingMadness"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Typing Madness</string>
  <key>CFBundleDisplayName</key><string>Typing Madness</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>TypingMadness</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
echo "Run it:  open \"$APP\""
