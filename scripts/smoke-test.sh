#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null || { echo "Install ffmpeg to generate test fixtures"; exit 1; }
swift build --product MediaLens
BIN="$(swift build --show-bin-path)/MediaLens"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
ffmpeg -v error -f lavfi -i testsrc2=size=640x360:rate=30000/1001 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 1 -c:v libx264 -c:a aac -metadata title="中文演示" "$TEMP_DIR/中文 sample.mp4"
ffmpeg -v error -f lavfi -i sine=frequency=440:sample_rate=44100 -t 0.2 "$TEMP_DIR/audio.wav"
ffmpeg -v error -f lavfi -i color=c=blue:s=320x240 -frames:v 1 -threads 1 "$TEMP_DIR/image.png"
cat > "$TEMP_DIR/captions.srt" <<'EOF'
1
00:00:00,000 --> 00:00:00,900
Hello MediaLens
EOF
cat > "$TEMP_DIR/chapters.txt" <<'EOF'
;FFMETADATA1
[CHAPTER]
TIMEBASE=1/1000
START=0
END=900
title=Opening
EOF
ffmpeg -v error -i "$TEMP_DIR/中文 sample.mp4" -i "$TEMP_DIR/captions.srt" -i "$TEMP_DIR/chapters.txt" -map 0 -map 1 -map_metadata 2 -map_chapters 2 -c copy "$TEMP_DIR/chapters.mkv"
"$BIN" --inspect "$TEMP_DIR/中文 sample.mp4" > "$TEMP_DIR/video.json"
"$BIN" --inspect "$TEMP_DIR/chapters.mkv" > "$TEMP_DIR/mkv.json"
"$BIN" --inspect "$TEMP_DIR/audio.wav" --native > "$TEMP_DIR/audio.json"
"$BIN" --inspect "$TEMP_DIR/image.png" --native > "$TEMP_DIR/image.json"
printf 'not media' > "$TEMP_DIR/invalid.txt"
if "$BIN" --inspect "$TEMP_DIR/invalid.txt" > /dev/null 2>&1; then echo "Invalid file unexpectedly passed"; exit 1; fi
python3 - "$TEMP_DIR" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
video = json.loads((p / 'video.json').read_text())
assert {s['codec_type'] for s in video['streams']} == {'video', 'audio'}
assert video['streams'][0]['width'] == 640
assert video['format']['tags']['title'] == '中文演示'
mkv = json.loads((p / 'mkv.json').read_text())
assert any(s['codec_type'] == 'subtitle' for s in mkv['streams'])
assert mkv['chapters'][0]['tags']['title'] == 'Opening'
for name in ['audio', 'image']:
    native = json.loads((p / f'{name}.json').read_text())
    assert native['engine'] == 'Apple frameworks'
    assert len(native['sections']) >= 2
print('PASS: MP4, MKV subtitles/chapters, native WAV/PNG, invalid file, Unicode paths')
PY
