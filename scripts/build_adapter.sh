#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/Vendor/MediaRemoteAdapter"
if [[ ! -d "$VENDOR/.git" ]]; then
  git clone --depth 1 https://github.com/ungive/mediaremote-adapter.git "$VENDOR"
fi
mkdir -p "$VENDOR/build"
cd "$VENDOR/build"
cmake ..
cmake --build .
cp -R MediaRemoteAdapter.framework "$VENDOR/" 2>/dev/null || true
find . -name 'MediaRemoteAdapter.framework' -maxdepth 3 -exec cp -R {} "$VENDOR/" \;
cp "$VENDOR/bin/mediaremote-adapter.pl" "$VENDOR/mediaremote-adapter.pl"
echo "Adapter ready in $VENDOR"
