#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.build-src/olcrtc"

rm -rf "$SRC" "$ROOT/Frameworks/Mobile.xcframework"
mkdir -p "$ROOT/.build-src" "$ROOT/Frameworks"

git clone --depth 1 https://github.com/openlibrecommunity/olcrtc "$SRC"

pushd "$SRC"
gomobile bind \
  -target=ios \
  -iosversion=16.0 \
  -ldflags="-s -w -checklinkname=0" \
  -o "$ROOT/Frameworks/Mobile.xcframework" \
  ./mobile
popd

test -d "$ROOT/Frameworks/Mobile.xcframework"
echo "Built: Frameworks/Mobile.xcframework"
