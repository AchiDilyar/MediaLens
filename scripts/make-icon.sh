#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="Assets/AppIcon.png"
[ -f "$SOURCE" ] || { echo "Missing final icon resource: Assets/AppIcon.png"; exit 1; }
mkdir -p dist/AppIcon/MediaLens.iconset
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift scripts/Icon.swift "$SOURCE" dist/AppIcon/icon-1024.png
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" dist/AppIcon/icon-1024.png --out "dist/AppIcon/MediaLens.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" dist/AppIcon/icon-1024.png --out "dist/AppIcon/MediaLens.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns dist/AppIcon/MediaLens.iconset -o dist/AppIcon/MediaLens.icns
