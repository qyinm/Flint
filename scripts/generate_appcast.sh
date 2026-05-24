#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/load_release_env.sh"
load_release_env "$ROOT_DIR"

VERSION="${FLINT_VERSION:-0.1.0}"
TAG="v${VERSION#v}"
DIST_DIR="$ROOT_DIR/dist"
APPCAST_DIR="$DIST_DIR/appcast"
ZIP_NAME="Flint-${VERSION#v}-mac-arm64.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
NOTES_PATH="${FLINT_RELEASE_NOTES_PATH:-$DIST_DIR/release-notes-${TAG}.md}"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-app.flint.Flint}"
SPARKLE_GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast}"
DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-https://github.com/qyinm/Flint/releases/download/${TAG}/}"
FULL_RELEASE_NOTES_URL="${SPARKLE_FULL_RELEASE_NOTES_URL:-https://github.com/qyinm/Flint/releases/tag/${TAG}}"
APPCAST_PATH="$APPCAST_DIR/appcast.xml"

if [[ ! -x "$SPARKLE_GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast was not found at $SPARKLE_GENERATE_APPCAST." >&2
  echo "Run swift build first so SwiftPM downloads Sparkle's binary artifact." >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Expected Sparkle update archive does not exist: $ZIP_PATH" >&2
  exit 1
fi

rm -rf "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$ZIP_PATH" "$APPCAST_DIR/$ZIP_NAME"

if [[ -f "$NOTES_PATH" ]]; then
  cp "$NOTES_PATH" "$APPCAST_DIR/${ZIP_NAME%.zip}.md"
fi

"$SPARKLE_GENERATE_APPCAST" \
  --account "$SPARKLE_ACCOUNT" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --full-release-notes-url "$FULL_RELEASE_NOTES_URL" \
  --embed-release-notes \
  -o "$APPCAST_PATH" \
  "$APPCAST_DIR"

echo "$APPCAST_PATH"
