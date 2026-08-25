#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/work/release-build"
APP_NAME="VideoHarbor"
FINAL_APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
STAGING_ROOT="$(mktemp -d "$PROJECT_DIR/work/release-staging.XXXXXX")"
APP_BUNDLE="$STAGING_ROOT/$APP_NAME.app"
APP_MACOS="$APP_BUNDLE/Contents/MacOS"
APP_RESOURCES="$APP_BUNDLE/Contents/Resources"
SDK_PATH="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macos14.0"

mkdir -p "$BUILD_DIR"

required_tools=(yt-dlp ffmpeg ffprobe node)
for required_tool in "${required_tools[@]}"; do
    if [[ ! -x "$PROJECT_DIR/Resources/Tools/$required_tool" ]]; then
        echo "Missing bundled tool: Resources/Tools/$required_tool" >&2
        echo "Run ./scripts/bootstrap_tools.sh before ./build.sh." >&2
        exit 1
    fi
done

echo "[1/6] Building VideoHarbor"
swiftc \
    -swift-version 5 \
    -target "$TARGET" \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    -O \
    -whole-module-optimization \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -framework QuartzCore \
    -framework UniformTypeIdentifiers \
    "$PROJECT_DIR"/Sources/VideoHarborCore/*.swift \
    "$PROJECT_DIR"/Sources/VideoHarbor/*.swift \
    -Xlinker -dead_strip \
    -o "$BUILD_DIR/$APP_NAME"

echo "[2/6] Building app icon"
cp "$PROJECT_DIR/Resources/AppIcon.png" "$BUILD_DIR/AppIcon.png"
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -s format png -z 16 16 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$BUILD_DIR/AppIcon.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$BUILD_DIR/AppIcon.icns"

echo "[3/6] Assembling bundle"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_DIR/$APP_NAME" "$APP_MACOS/$APP_NAME"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
cp "$PROJECT_DIR/Resources/THIRD_PARTY_NOTICES.md" "$APP_RESOURCES/THIRD_PARTY_NOTICES.md"
cp -R "$PROJECT_DIR/Resources/Licenses" "$APP_RESOURCES/Licenses"
cp -R "$PROJECT_DIR/Resources/Tools" "$APP_RESOURCES/Tools"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

echo "[4/6] Signing nested tools"
# Some bundled release binaries are intentionally read-only. Work only on the
# staging copy so xattr/codesign can update metadata without touching the source.
chmod -R u+w "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE"
while IFS= read -r -d '' binary; do
    if file -b "$binary" | grep -q 'Mach-O'; then
        if ! codesign --verify --strict "$binary" >/dev/null 2>&1; then
            codesign --force --sign - "$binary"
        fi
        codesign --verify --strict "$binary"
    fi
done < <(find "$APP_RESOURCES/Tools" -type f -print0)

echo "[5/6] Signing and verifying app"
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
plutil -lint "$APP_BUNDLE/Contents/Info.plist"
"$APP_RESOURCES/Tools/ffmpeg" -version >/dev/null
"$APP_RESOURCES/Tools/ffprobe" -version >/dev/null
"$APP_RESOURCES/Tools/yt-dlp" --version >/dev/null
"$APP_RESOURCES/Tools/node" --version >/dev/null

echo "[6/6] Running core tests"
"$PROJECT_DIR/test.sh"

if [[ -e "$FINAL_APP_BUNDLE" ]]; then
    PREVIOUS_DIR="$PROJECT_DIR/work/previous-builds"
    mkdir -p "$PREVIOUS_DIR"
    mv "$FINAL_APP_BUNDLE" "$PREVIOUS_DIR/$APP_NAME-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
mv "$APP_BUNDLE" "$FINAL_APP_BUNDLE"

echo "Built: $FINAL_APP_BUNDLE"
