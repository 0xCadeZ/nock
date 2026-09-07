#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Nock.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
BIN="$ROOT/.build/release/Nock"

cd "$ROOT"
swift build -c release --product Nock

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

cp "$BIN" "$MACOS/Nock"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

if [[ -f "$BUILD/AppIcon.icns" ]]; then
  cp "$BUILD/AppIcon.icns" "$RES/AppIcon.icns"
elif [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RES/AppIcon.icns"
fi

if [[ -d "$ROOT/Vendor/MediaRemoteAdapter/MediaRemoteAdapter.framework" ]]; then
  mkdir -p "$CONTENTS/Frameworks"
  cp -R "$ROOT/Vendor/MediaRemoteAdapter/MediaRemoteAdapter.framework" "$CONTENTS/Frameworks/"
fi
if [[ -f "$ROOT/Vendor/MediaRemoteAdapter/mediaremote-adapter.pl" ]]; then
  cp "$ROOT/Vendor/MediaRemoteAdapter/mediaremote-adapter.pl" "$RES/mediaremote-adapter.pl"
fi

cat > "$CONTENTS/PkgInfo" <<'EOF'
APPL????
EOF

chmod +x "$MACOS/Nock"

if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP" 2>/dev/null || true
fi

echo "Built $APP"
