#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
DMG="$ROOT/dist/MediaLens.dmg"
(cd dist && shasum -a 256 -c MediaLens.dmg.sha256)
hdiutil verify "$DMG" -quiet
TEMP_DIR="$(mktemp -d)"
MOUNT="$TEMP_DIR/mount"
MOUNTED=0
cleanup() {
    if [ "$MOUNTED" = 1 ]; then hdiutil detach "$MOUNT" -quiet || true; fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT
mkdir -p "$MOUNT"
hdiutil attach "$DMG" -quiet -readonly -nobrowse -noautoopen -mountpoint "$MOUNT"
MOUNTED=1
APP="$MOUNT/MediaLens.app"
[ "$(readlink "$MOUNT/Applications")" = '/Applications' ]
[ -s "$MOUNT/.background/installer.png" ]
[ -s "$MOUNT/.DS_Store" ]
for bin in "$APP/Contents/MacOS/MediaLens" "$APP/Contents/Resources/bin/ffprobe"; do
    lipo "$bin" -verify_arch arm64 x86_64
done
codesign --verify --deep --strict "$APP"
# Confirm the mounted bundle itself finds and runs the bundled engine.
[ "$("$APP/Contents/MacOS/MediaLens" --engine-path)" = "$APP/Contents/Resources/bin/ffprobe" ]
"$APP/Contents/Resources/bin/ffprobe" -version > /dev/null 2>&1
"$ROOT/.build/dmg-tools/bin/python" - "$MOUNT" <<'PY'
from pathlib import Path
from ds_store import DSStore
import sys
volume = Path(sys.argv[1])
with DSStore.open(str(volume / '.DS_Store'), 'r') as store:
    assert store['MediaLens.app']['Iloc'] == (220, 232)
    assert store['Applications']['Iloc'] == (540, 232)
    assert store['.']['icvp']['backgroundType'] == 2
    assert store['.']['icvp']['iconSize'] == 104.0
    assert store['.']['icvp']['backgroundColorRed'] == 1.0
    assert '{760, 560}' in store['.']['bwsp']['WindowBounds']
    assert store['.']['bwsp']['ShowToolbar'] is False
print('PASS: DMG checksum, mount, universal App/engine, signature, Applications shortcut, installer layout')
PY
