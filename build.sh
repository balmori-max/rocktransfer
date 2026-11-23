#!/bin/zsh
# Builds RockSync.app as a universal app (Apple silicon + Intel). Needs only the Xcode Command Line Tools.
set -e
cd "$(dirname "$0")"
APP="build/RockSync.app"
VERSION="${VERSION:-1.0}"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library -target $arch-apple-macos14.0 Sources/*.swift -o build/obj/RockSync-$arch
done
lipo -create build/obj/RockSync-arm64 build/obj/RockSync-x86_64 -output "$APP/Contents/MacOS/RockSync"

# Icon + artwork, drawn by the app's own views
swiftc -O -swift-version 5 -parse-as-library Sources/Engine.swift Sources/Model.swift Sources/Theme.swift Sources/Views.swift Tools/render.swift -o build/obj/render
RS_LANG=en build/obj/render art >/dev/null
ICONSET=build/obj/AppIcon.iconset; mkdir -p $ICONSET
for s in 16 32 128 256 512; do
  sips -z $s $s art/icon-1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) art/icon-1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>RockSync</string>
  <key>CFBundleDisplayName</key><string>RockSync</string>
  <key>CFBundleIdentifier</key><string>io.github.balmori-max.rocksync</string>
  <key>CFBundleExecutable</key><string>RockSync</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
  <key>NSDocumentsFolderUsageDescription</key><string>To read your music folder and copy it to your iPod.</string>
  <key>NSRemovableVolumesUsageDescription</key><string>To read and copy music on your iPod.</string>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$APP"
(cd build && ditto -c -k --keepParent RockSync.app RockSync.zip)
echo "OK: $APP  and  build/RockSync.zip"
