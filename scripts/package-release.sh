#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# A formal release always includes both architectures, regardless of local dev settings.
CONFIGURATION=release APP_ARCHS='arm64 x86_64' bash scripts/build-app.sh
bash scripts/check-bundled-engine.sh
bash scripts/make-dmg.sh
bash scripts/check-dmg.sh
