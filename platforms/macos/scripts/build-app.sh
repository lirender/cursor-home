#!/usr/bin/env bash
#
# build-app.sh — Build CursorHome.app bundle from Swift package
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/CursorHome.app"

# Defaults
SIGN_MODE="adhoc"
SIGN_IDENTITY="-"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --no-sign             Skip code signing
  --sign-identity=ID    Sign with the given identity (default: ad-hoc)
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-sign)
            SIGN_MODE="none"
            shift
            ;;
        --sign-identity=*)
            SIGN_IDENTITY="${1#*=}"
            SIGN_MODE="identity"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

echo "==> Building CursorHome (release)..."
cd "$PROJECT_DIR"
swift build -c release

echo "==> Assembling .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
BINARY="$PROJECT_DIR/.build/release/CursorHome"
if [[ ! -f "$BINARY" ]]; then
    # Try arch-specific path
    BINARY="$(find "$PROJECT_DIR/.build" -path '*/release/CursorHome' -type f | head -1)"
fi
if [[ -z "$BINARY" || ! -f "$BINARY" ]]; then
    echo "Error: Cannot find release binary" >&2
    exit 1
fi
cp "$BINARY" "$APP_DIR/Contents/MacOS/CursorHome"

# Resolve Info.plist variables
echo "==> Resolving Info.plist..."
sed \
    -e 's/\$(DEVELOPMENT_LANGUAGE)/en/g' \
    -e 's/\$(EXECUTABLE_NAME)/CursorHome/g' \
    -e 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.cursorhome.macos/g' \
    -e 's/\$(PRODUCT_NAME)/CursorHome/g' \
    -e 's/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g' \
    -e 's/\$(MACOSX_DEPLOYMENT_TARGET)/14.0/g' \
    "$PROJECT_DIR/Sources/CursorHome/Info.plist" \
    > "$APP_DIR/Contents/Info.plist"

# PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Copy SPM resource bundle if it exists (inside Contents/Resources for proper signing)
RESOURCE_BUNDLE="$(find "$PROJECT_DIR/.build" -path '*/release/CursorHome_CursorHome.bundle' -type d 2>/dev/null | grep -v index-build | head -1)"
if [[ -n "$RESOURCE_BUNDLE" && -d "$RESOURCE_BUNDLE" ]]; then
    echo "==> Copying resource bundle..."
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/CursorHome_CursorHome.bundle"
else
    echo "Warning: SPM resource bundle not found — app icons may be missing"
fi

# Check for app icon
if [[ -d "$APP_DIR/Contents/Resources/CursorHome_CursorHome.bundle" ]]; then
    ICON_COUNT="$(find "$APP_DIR/Contents/Resources/CursorHome_CursorHome.bundle" -name '*.png' -o -name '*.icns' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$ICON_COUNT" -eq 0 ]]; then
        echo "Warning: No icon images found in resource bundle — add PNGs to Assets.xcassets"
    fi
fi

# Code signing
case "$SIGN_MODE" in
    adhoc)
        echo "==> Ad-hoc code signing..."
        codesign --force --deep --sign - "$APP_DIR"
        ;;
    identity)
        echo "==> Code signing with identity: $SIGN_IDENTITY"
        codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
        ;;
    none)
        echo "==> Skipping code signing"
        ;;
esac

echo "==> Built: $APP_DIR"
echo "    Run with: open $APP_DIR"
