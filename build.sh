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
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

echo "빌드 완료: $APP_DIR"
