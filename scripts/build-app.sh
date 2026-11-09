#!/bin/bash
# Construit build/Metrixator.app (à lancer sur un Mac avec Xcode ou les Command Line Tools).
#   ./scripts/build-app.sh            → app pour l'architecture du Mac
#   ./scripts/build-app.sh --install  → copie aussi l'app dans /Applications
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ Compilation (release)…"
swift build -c release --product Metrixator
BIN_DIR=$(swift build -c release --show-bin-path)

APP=build/Metrixator.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Metrixator" "$APP/Contents/MacOS/Metrixator"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "▸ Icône…"
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "▸ Signature locale (ad hoc)…"
codesign --force --deep --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/Metrixator.app
  cp -R "$APP" /Applications/
  echo "✓ Installée dans /Applications/Metrixator.app"
fi
echo "✓ $APP prête. Ouvrez-la avec : open $APP"
