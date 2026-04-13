#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/mac"
BUNDLE_DIR="$APP_DIR/build/TypingLens.app"

pushd "$APP_DIR" >/dev/null
swift build -c debug --product TypingLensMac
BIN_DIR="$(swift build -c debug --show-bin-path)"
popd >/dev/null

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS" "$BUNDLE_DIR/Contents/Resources"

cp "$APP_DIR/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
cp "$BIN_DIR/TypingLensMac" "$BUNDLE_DIR/Contents/MacOS/TypingLensMac"
chmod +x "$BUNDLE_DIR/Contents/MacOS/TypingLensMac"

codesign --force --deep --sign - "$BUNDLE_DIR" >/dev/null

echo "Built app bundle: $BUNDLE_DIR"
