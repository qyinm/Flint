#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Flint"
PRODUCT_NAME="FlintApp"
BUNDLE_ID="app.flint.Flint"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/ModuleCache.noindex}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$ROOT_DIR/.build/ModuleCache.noindex}"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

kill_running_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

stage_app_bundle() {
  local build_dir
  build_dir="$(swift build --show-bin-path)"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_FRAMEWORKS" "$APP_RESOURCES/templates"

  cp "$build_dir/$PRODUCT_NAME" "$APP_BINARY"
  chmod +x "$APP_BINARY"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY" 2>/dev/null || true

  if [[ -d "$build_dir/Sparkle.framework" ]]; then
    cp -R "$build_dir/Sparkle.framework" "$APP_FRAMEWORKS/Sparkle.framework"
  fi

  if [[ -d "$build_dir/Flint_FlintApp.bundle" ]]; then
    cp -R "$build_dir/Flint_FlintApp.bundle" "$APP_RESOURCES/Flint_FlintApp.bundle"
  fi

  while IFS= read -r template_path; do
    cp "$ROOT_DIR/$template_path" "$APP_RESOURCES/templates/"
  done < <(git -C "$ROOT_DIR" ls-files 'templates/*.yaml' 'templates/*.yml')

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

sign_app_bundle() {
  if [[ -d "$APP_FRAMEWORKS/Sparkle.framework" ]]; then
    codesign --force --sign - "$APP_FRAMEWORKS/Sparkle.framework" >/dev/null
  fi
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
}

cd "$ROOT_DIR"
kill_running_app
swift build
stage_app_bundle
sign_app_bundle

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    usage
    exit 2
    ;;
esac
