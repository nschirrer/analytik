#!/bin/bash
# Compile Analytik en release (binaire universel) et assemble dist/Analytik.app + un zip.
# Usage : VERSION=0.1.0 BUILD_NUMBER=42 bash scripts/bundle.sh   (macOS uniquement)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0}"
BUILD="${BUILD_NUMBER:-1}"
APP="dist/Analytik.app"

echo "→ Compilation release (arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64 --product Analytik
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --product Analytik --show-bin-path)"
echo "   binaire : $BIN_DIR/Analytik"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/fr.lproj"
cp "$BIN_DIR/Analytik" "$APP/Contents/MacOS/Analytik"
chmod +x "$APP/Contents/MacOS/Analytik"
lipo -info "$APP/Contents/MacOS/Analytik"

ICON_KEY=""
if [ -f Resources/AppIcon-1024.png ]; then
  echo "→ Icône…"
  ICONSET="dist/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" Resources/AppIcon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" Resources/AppIcon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>fr</string>
  <key>CFBundleExecutable</key><string>Analytik</string>
  <key>CFBundleIdentifier</key><string>com.nschirrer.analytik</string>
  <key>CFBundleName</key><string>Analytik</string>
  <key>CFBundleDisplayName</key><string>Analytik</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>14.4</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.business</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Analytik</string>
  ${ICON_KEY}
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Classeur Excel</string>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key><array><string>org.openxmlformats.spreadsheetml.sheet</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "→ Signature ad hoc…"
codesign --force --sign - "$APP"
codesign --verify --verbose "$APP"

ZIP="dist/Analytik-${VERSION}-macOS.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "✓ $ZIP"
ls -la dist
