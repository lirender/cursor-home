#!/usr/bin/env bash
#
# build-dmg.sh — Create a .dmg disk image containing CursorHome.app
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/CursorHome.app"

VERSION="1.0.0"
DMG_NAME="CursorHome-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
VOLUME_NAME="CursorHome"

# Build .app first if it doesn't exist
if [[ ! -d "$APP_DIR" ]]; then
    echo "==> .app bundle not found, building first..."
    "$SCRIPT_DIR/build-app.sh"
fi

echo "==> Creating DMG..."

# Create staging directory
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP_DIR" "$STAGING/CursorHome.app"
ln -s /Applications "$STAGING/Applications"

# Remove any existing DMG
rm -f "$DMG_PATH"

# Create DMG
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "==> Built: $DMG_PATH"
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"
