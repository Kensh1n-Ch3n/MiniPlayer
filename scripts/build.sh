#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LICENSE_FILE="$ROOT/LICENSE"
cd "$ROOT"

CONFIG="${1:-release}"
APP="$ROOT/dist/MiniPlayer.app"
ZIP="$ROOT/dist/MiniPlayer.zip"

echo "==> Building MiniPlayer ($CONFIG)"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/MiniPlayer"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "==> Generating app icon"
  PYTHON="${PYTHON:-python3}"
  "$PYTHON" "$ROOT/scripts/make_icon.py"
fi

echo "==> Assembling app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MiniPlayer"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/alipay-qr.jpg" "$APP/Contents/Resources/alipay-qr.jpg"
cp "$LICENSE_FILE" "$APP/Contents/Resources/LICENSE.txt"
chmod +x "$APP/Contents/MacOS/MiniPlayer"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> Signing"
xattr -cr "$APP" 2>/dev/null || true
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -n 1)"
if [[ -n "$IDENTITY" ]]; then
  echo "    using: $IDENTITY"
  codesign --force --deep --sign "$IDENTITY" --timestamp=none "$APP"
else
  echo "    no signing identity found, using ad-hoc signature"
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"

echo "==> Packaging"
mkdir -p "$ROOT/dist"
rm -f "$ZIP"
cp "$LICENSE_FILE" "$ROOT/dist/LICENSE"
(
  cd "$ROOT/dist"
  zip -r -q "$ZIP" "MiniPlayer.app" "LICENSE"
)


echo
echo "App:  $APP"
echo "Zip:  $ZIP"
echo
echo "Launch with: open \"$APP\""
