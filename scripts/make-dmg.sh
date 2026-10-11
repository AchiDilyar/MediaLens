#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/dist/MediaLens.app"
DMG="$ROOT/dist/MediaLens.dmg"
[ -d "$APP" ] || { echo 'Build MediaLens.app first' >&2; exit 1; }
for bin in "$APP/Contents/MacOS/MediaLens" "$APP/Contents/Resources/bin/ffprobe"; do
    lipo "$bin" -verify_arch arm64 x86_64
done
# Python packages are isolated build tools; they are not App dependencies.
PYTHON="${DMG_PYTHON:-python3}"
TOOLS="$ROOT/.build/dmg-tools"
if [ ! -x "$TOOLS/bin/python" ]; then "$PYTHON" -m venv "$TOOLS"; fi
if ! "$TOOLS/bin/python" -c 'import ds_store, mac_alias' 2>/dev/null; then
    "$TOOLS/bin/python" -m pip install --disable-pip-version-check -r scripts/dmg-requirements.txt
fi
TEMP_DIR="$(mktemp -d)"
MOUNT="$TEMP_DIR/mount"
MOUNTED=0
cleanup() {
    if [ "$MOUNTED" = 1 ]; then hdiutil detach "$MOUNT" -quiet || true; fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT
mkdir -p "$TEMP_DIR/stage/.background" "$MOUNT"
ditto "$APP" "$TEMP_DIR/stage/MediaLens.app"
ln -s /Applications "$TEMP_DIR/stage/Applications"
CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache" swift scripts/DMGArtwork.swift "$TEMP_DIR/stage/.background/installer.png"
hdiutil create -quiet -volname MediaLens -fs HFS+ -srcfolder "$TEMP_DIR/stage" -format UDRW "$TEMP_DIR/installer.dmg"
hdiutil attach "$TEMP_DIR/installer.dmg" -quiet -nobrowse -noautoopen -mountpoint "$MOUNT"
MOUNTED=1
"$TOOLS/bin/python" scripts/dmg-layout.py "$MOUNT"
sync --file-system "$MOUNT"
hdiutil detach "$MOUNT" -quiet
MOUNTED=0
# Build atomically; leave an earlier release intact if conversion fails.
hdiutil convert "$TEMP_DIR/installer.dmg" -quiet -format UDZO -imagekey zlib-level=9 -o "$TEMP_DIR/MediaLens.dmg"
if [ "${SIGNING_IDENTITY:--}" != '-' ]; then
    codesign --sign "$SIGNING_IDENTITY" --timestamp "$TEMP_DIR/MediaLens.dmg"
fi
mv "$TEMP_DIR/MediaLens.dmg" "$DMG"
(cd dist && shasum -a 256 MediaLens.dmg > MediaLens.dmg.sha256)
echo "Universal DMG: $DMG"
