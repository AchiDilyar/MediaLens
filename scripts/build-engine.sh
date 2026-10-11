#!/bin/bash
# Build a standalone LGPL ffprobe, with no Homebrew dylib dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
VERSION=8.0.1
SHA256=05ee0b03119b45c0bdb4df654b96802e909e0a752f72e4fe3794f487229e5a41
ENGINE="$ROOT/dist/Engine"
ARCH="${ENGINE_ARCH:-$(uname -m)}"
case "$ARCH" in
    arm64) FFMPEG_ARCH=aarch64 ;;
    x86_64) FFMPEG_ARCH=x86_64 ;;
    *) echo "Unsupported engine architecture: $ARCH" >&2; exit 1 ;;
esac
SOURCE="$ENGINE/ffmpeg-$VERSION.tar.xz"
WORK="$ROOT/.build/ffprobe-$VERSION-$ARCH"
mkdir -p "$ENGINE/$ARCH"
if [ ! -f "$SOURCE" ]; then
    curl --fail --location --retry 3 "https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.xz" -o "$SOURCE.download"
    mv "$SOURCE.download" "$SOURCE"
fi
printf '%s  %s\n' "$SHA256" "$SOURCE" | shasum -a 256 -c -
RECIPE_SHA="$(shasum -a 256 scripts/build-engine.sh | awk '{print $1}')"
if [ ! -x "$ENGINE/$ARCH/ffprobe" ] || [ "$(cat "$ENGINE/$ARCH/recipe.sha256" 2>/dev/null || true)" != "$RECIPE_SHA" ]; then
    rm -rf "$WORK"
    mkdir -p "$WORK"
    tar -xf "$SOURCE" -C "$WORK" --strip-components=1
    (
        cd "$WORK"
        ./configure --cc=clang --host-cc=clang --enable-cross-compile --target-os=darwin --arch="$FFMPEG_ARCH" \
            --disable-autodetect --disable-shared --enable-static \
            --disable-gpl --disable-nonfree --disable-version3 --disable-network --enable-zlib \
            --disable-doc --disable-debug --disable-programs --enable-ffprobe \
            --disable-avdevice --disable-avfilter \
            --disable-encoders --disable-muxers --disable-protocols \
            --enable-protocol=file,crypto,data --disable-x86asm \
            --extra-cflags="-arch $ARCH -mmacosx-version-min=14.0" --extra-ldflags="-arch $ARCH -mmacosx-version-min=14.0" \
            > "$ENGINE/configure-$ARCH.log" 2>&1
        make -j "${ENGINE_JOBS:-4}" ffprobe > "$ENGINE/build-$ARCH.log" 2>&1
    )
    cp "$WORK/ffprobe" "$ENGINE/$ARCH/ffprobe"
    cp "$WORK/COPYING.LGPLv2.1" "$ENGINE/COPYING.LGPLv2.1"
    cp "$WORK/LICENSE.md" "$ENGINE/LICENSE.md"
    printf '%s\n' "$RECIPE_SHA" > "$ENGINE/$ARCH/recipe.sha256"
fi
# Never package a binary that requires libraries from a developer's machine.
if otool -L "$ENGINE/$ARCH/ffprobe" | tail -n +2 | awk '{print $1}' | grep -Ev '^(/usr/lib/|/System/Library/)' ; then
    echo 'Unexpected non-system dependency in ffprobe' >&2
    exit 1
fi
lipo "$ENGINE/$ARCH/ffprobe" -verify_arch "$ARCH"
# Cross-compiled slices need not execute on the build host.
{
    printf 'FFmpeg %s / architecture %s / macOS 14+\nSource SHA-256: %s\n' "$VERSION" "$ARCH" "$SHA256"
    cat "$WORK/ffbuild/config.sh"
} > "$ENGINE/$ARCH/BUILD-INFO.txt"
echo "Engine: $ENGINE/$ARCH/ffprobe"
