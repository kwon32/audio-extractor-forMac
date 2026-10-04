#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP_NAME="AudioExtractor"
INSTALL_DIR="/Users/kwon/Applications"
APP_DIR="$INSTALL_DIR/$APP_NAME.app"

mkdir -p "$INSTALL_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
swiftc "$SCRIPT_DIR/Sources/main.swift" \
  -o "$APP_DIR/Contents/MacOS/AudioExtractor" \
  -target arm64-apple-macosx13.0 \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  -O
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$SCRIPT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$SCRIPT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
rm -rf "${ICONSET:h}"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

echo "빌드 완료: $APP_DIR"
