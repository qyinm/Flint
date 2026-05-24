#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/load_release_env.sh"
load_release_env "$ROOT_DIR"

VERSION="${FLINT_VERSION:-0.1.0}"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/Flint.app"
DMG_STAGING_DIR="$DIST_DIR/dmg-root"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/Flint-${VERSION}-mac-arm64.zip"
DMG_PATH="$DIST_DIR/Flint-${VERSION}-mac-arm64.dmg"
APP_ICON_SOURCE="$ROOT_DIR/app-logo.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
NOTARIZE="${FLINT_NOTARIZE:-0}"
SIGN_IDENTITY="${FLINT_SIGN_IDENTITY:-}"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-app.flint.Flint}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-aJeg9bByRLbidg8vT0uAu6uIONxwlrPSWphL/AkqCQE=}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/qyinm/Flint/releases/latest/download/appcast.xml}"

require_notarization_config() {
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "FLINT_SIGN_IDENTITY is required when FLINT_NOTARIZE=1." >&2
    echo "Expected a Developer ID Application identity from: security find-identity -v -p codesigning" >&2
    exit 1
  fi

  if ! security find-identity -v -p codesigning | grep -Fq "$SIGN_IDENTITY"; then
    echo "Signing identity not found: $SIGN_IDENTITY" >&2
    security find-identity -v -p codesigning >&2
    exit 1
  fi

  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, and APPLE_TEAM_ID are required when FLINT_NOTARIZE=1." >&2
    exit 1
  fi
}

notarize_artifact() {
  local artifact_path="$1"
  xcrun notarytool submit "$artifact_path" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
}

if [[ "$NOTARIZE" == "1" ]]; then
  require_notarization_config
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/ModuleCache.noindex}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$ROOT_DIR/.build/ModuleCache.noindex}"

swift build -c release

rm -rf "$APP_DIR" "$DMG_STAGING_DIR" "$ICONSET_DIR" "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/FlintApp" "$MACOS_DIR/Flint"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/Flint" 2>/dev/null || true
cp -R "$BUILD_DIR/Sparkle.framework" "$FRAMEWORKS_DIR/Sparkle.framework"
cp -R "$BUILD_DIR/Flint_FlintApp.bundle" "$RESOURCES_DIR/Flint_FlintApp.bundle"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$APP_ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$APP_ICON_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
mkdir -p "$RESOURCES_DIR/templates"
while IFS= read -r template_path; do
  cp "$ROOT_DIR/$template_path" "$RESOURCES_DIR/templates/"
done < <(git ls-files 'templates/*.yaml' 'templates/*.yml')

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Flint</string>
  <key>CFBundleIdentifier</key>
  <string>app.flint.Flint</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Flint</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUFeedURL</key>
  <string>${SPARKLE_FEED_URL}</string>
  <key>SUPublicEDKey</key>
  <string>${SPARKLE_PUBLIC_ED_KEY}</string>
</dict>
</plist>
PLIST

if [[ "$NOTARIZE" == "1" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$FRAMEWORKS_DIR/Sparkle.framework"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
else
  codesign --force --sign - "$FRAMEWORKS_DIR/Sparkle.framework"
  codesign --force --sign - "$APP_DIR"
fi

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
  notarize_artifact "$ZIP_PATH"
  xcrun stapler staple "$APP_DIR"
fi

mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/Flint.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create \
  -volname "Flint ${VERSION}" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  notarize_artifact "$DMG_PATH"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$APP_DIR"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type execute --verbose=4 "$APP_DIR"
fi

echo "$APP_DIR"
echo "$ZIP_PATH"
echo "$DMG_PATH"
