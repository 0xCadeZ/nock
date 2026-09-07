#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  SRC=$(ls -1 "$ROOT"/../.grok/sessions/*/images/1.jpg 2>/dev/null | tail -1 || true)
fi
if [[ -z "$SRC" || ! -f "$SRC" ]]; then
  echo "No source image" >&2
  exit 1
fi
SET="$ROOT/build/Nock.iconset"
rm -rf "$SET"
mkdir -p "$SET"
png() { sips -s format png -z "$1" "$1" "$SRC" --out "$2" >/dev/null; }
png 16   "$SET/icon_16x16.png"
png 32   "$SET/icon_16x16@2x.png"
png 32   "$SET/icon_32x32.png"
png 64   "$SET/icon_32x32@2x.png"
png 128  "$SET/icon_128x128.png"
png 256  "$SET/icon_128x128@2x.png"
png 256  "$SET/icon_256x256.png"
png 512  "$SET/icon_256x256@2x.png"
png 512  "$SET/icon_512x512.png"
png 1024 "$SET/icon_512x512@2x.png"
if command -v iconutil >/dev/null; then
  iconutil -c icns "$SET" -o "$ROOT/build/AppIcon.icns"
  cp "$ROOT/build/AppIcon.icns" "$ROOT/Resources/AppIcon.icns"
  echo "Wrote Resources/AppIcon.icns"
else
  echo "iconutil missing; PNG iconset left in $SET"
fi
