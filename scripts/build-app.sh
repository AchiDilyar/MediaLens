#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIGURATION="${CONFIGURATION:-release}"
# Universal by default; developers can request one native slice to iterate faster.
ARCHS="${APP_ARCHS:-arm64 x86_64}"
APP="$PWD/dist/MediaLens.app"
SWIFT_INPUTS=()
ENGINE_INPUTS=()
for architecture in $ARCHS; do
    case "$architecture" in arm64|x86_64) ;; *) echo "Unsupported architecture: $architecture" >&2; exit 1 ;; esac
    ENGINE_ARCH="$architecture" bash scripts/build-engine.sh
    SCRATCH="$PWD/.build/app-$architecture"
    TRIPLE="$architecture-apple-macosx14.0"
    swift build -c "$CONFIGURATION" --product MediaLens --scratch-path "$SCRATCH" --triple "$TRIPLE"
    BIN_DIR="$(swift build -c "$CONFIGURATION" --scratch-path "$SCRATCH" --triple "$TRIPLE" --show-bin-path)"
    SWIFT_INPUTS+=("$BIN_DIR/MediaLens")
    ENGINE_INPUTS+=("$PWD/dist/Engine/$architecture/ffprobe")
done
bash scripts/make-icon.sh
# Recreate the bundle to prevent stale resources from earlier builds.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin" "$APP/Contents/Resources/ThirdParty/FFmpeg"
lipo -create "${SWIFT_INPUTS[@]}" -output "$APP/Contents/MacOS/MediaLens"
lipo -create "${ENGINE_INPUTS[@]}" -output "$APP/Contents/Resources/bin/ffprobe"
for architecture in $ARCHS; do
    lipo "$APP/Contents/MacOS/MediaLens" -verify_arch "$architecture"
    lipo "$APP/Contents/Resources/bin/ffprobe" -verify_arch "$architecture"
done
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp dist/AppIcon/MediaLens.icns "$APP/Contents/Resources/MediaLens.icns"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp dist/Engine/COPYING.LGPLv2.1 dist/Engine/LICENSE.md \
    dist/Engine/ffmpeg-8.0.1.tar.xz scripts/build-engine.sh \
    "$APP/Contents/Resources/ThirdParty/FFmpeg/"
: > "$APP/Contents/Resources/ThirdParty/FFmpeg/BUILD-INFO.txt"
for architecture in $ARCHS; do
    cat "dist/Engine/$architecture/BUILD-INFO.txt" >> "$APP/Contents/Resources/ThirdParty/FFmpeg/BUILD-INFO.txt"
done
cp docs/THIRD-PARTY.md "$APP/Contents/Resources/ThirdParty/README.md"
# Set SIGNING_IDENTITY only for a real Developer ID identity available in your keychain.
IDENTITY="${SIGNING_IDENTITY:--}"
sign_binary() {
    if [ "$IDENTITY" = '-' ]; then
        codesign --force --sign - "$1"
    else
        codesign --force --sign "$IDENTITY" --options runtime --timestamp "$1"
    fi
}
sign_binary "$APP/Contents/Resources/bin/ffprobe"
sign_binary "$APP"
codesign --verify --deep --strict "$APP"
echo "Built ($ARCHS): $APP"
