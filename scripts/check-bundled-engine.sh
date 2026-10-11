#!/bin/bash
# Relocate the App, restrict PATH, and verify real inspection with its bundled engine.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/MediaLens.app"
[ -x "$APP/Contents/Resources/bin/ffprobe" ] || { echo 'Build the complete App first'; exit 1; }
command -v ffmpeg >/dev/null || { echo 'Install ffmpeg to generate fixtures'; exit 1; }
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
ditto "$APP" "$TEMP_DIR/MediaLens.app"
BIN="$TEMP_DIR/MediaLens.app/Contents/MacOS/MediaLens"
ENGINE="$TEMP_DIR/MediaLens.app/Contents/Resources/bin/ffprobe"
THIRD_PARTY="$TEMP_DIR/MediaLens.app/Contents/Resources/ThirdParty/FFmpeg"
for name in COPYING.LGPLv2.1 LICENSE.md ffmpeg-8.0.1.tar.xz build-engine.sh BUILD-INFO.txt; do
    [ -s "$THIRD_PARTY/$name" ] || { echo "Missing: $name"; exit 1; }
done
if otool -L "$ENGINE" | awk '/^[[:space:]]+\// {print $1}' | grep -Ev '^(/usr/lib/|/System/Library/)'; then
    echo 'Non-system library dependency' >&2; exit 1
fi
[ "$(PATH=/usr/bin:/bin "$BIN" --engine-path)" = "$ENGINE" ] || { echo 'App did not select bundled ffprobe'; exit 1; }
"$ENGINE" -L > "$TEMP_DIR/engine-license.txt" 2>&1
grep 'Lesser General Public' "$TEMP_DIR/engine-license.txt" >/dev/null
ffmpeg -v error -f lavfi -i testsrc2=size=640x360:rate=24 -f lavfi -i sine=sample_rate=48000 -t 0.5 -c:v libx264 -c:a aac -metadata title="内置引擎验证" "$TEMP_DIR/中文 video.mp4"
ffmpeg -v error -i "$TEMP_DIR/中文 video.mp4" -c copy "$TEMP_DIR/video.mkv"
ffmpeg -v error -f lavfi -i sine=sample_rate=44100 -t 0.2 "$TEMP_DIR/audio.wav"
ffmpeg -v error -f lavfi -i color=c=blue:s=320x240 -frames:v 1 -threads 1 "$TEMP_DIR/image.png"
for name in '中文 video.mp4' video.mkv audio.wav image.png; do
    PATH=/usr/bin:/bin "$BIN" --inspect "$TEMP_DIR/$name" > "$TEMP_DIR/$name.json"
done
printf 'not a media file' > "$TEMP_DIR/invalid.txt"
if PATH=/usr/bin:/bin "$BIN" --inspect "$TEMP_DIR/invalid.txt" >/dev/null 2>&1; then
    echo 'Invalid file unexpectedly passed'; exit 1
fi
python3 - "$TEMP_DIR" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
for name in ['中文 video.mp4', 'video.mkv']:
    report = json.loads((root / (name + '.json')).read_text())
    assert {s['codec_type'] for s in report['streams']} == {'video', 'audio'}
    assert report['streams'][0]['width'] == 640
report = json.loads((root / '中文 video.mp4.json').read_text())
assert report['format']['tags']['title'] == '内置引擎验证'
assert json.loads((root / 'audio.wav.json').read_text())['streams'][0]['sample_rate'] == '44100'
assert json.loads((root / 'image.png.json').read_text())['streams'][0]['width'] == 320
print('PASS: relocated App, bundled engine, system libraries only, source/license materials, MP4/MKV/WAV/PNG, Unicode, invalid input')
PY
codesign --verify --deep --strict "$TEMP_DIR/MediaLens.app"
