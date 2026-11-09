#!/bin/sh
# Build Idea Box.app from Sources/main.swift.
#
#   ./scripts/build.sh            -> build/Idea Box.app
#   ./scripts/build.sh --install  -> also copy to ~/Applications and ad-hoc sign it
#
# Requires the Xcode Command Line Tools (swiftc, clang, codesign).
set -eu

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/build/Idea Box.app"
BIN="IdeaBox"

command -v swiftc >/dev/null 2>&1 || {
  echo "error: swiftc not found. Install the Xcode Command Line Tools:" >&2
  echo "       xcode-select --install" >&2
  exit 1
}

mkdir -p build
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/$BIN" Sources/main.swift -framework Cocoa
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: enough for a local build, no Developer ID required.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "built: $APP"

if [ "${1:-}" = "--install" ]; then
  DEST="$HOME/Applications/Idea Box.app"
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  codesign --force --sign - "$DEST" >/dev/null 2>&1 || true
  echo "installed: $DEST"
fi
