#!/usr/bin/env bash
#
# build-deb.sh — Build a .deb package for CursorHome
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DATA_DIR="$PROJECT_DIR/data"

# Read version from Cargo.toml
VERSION="$(grep '^version' "$PROJECT_DIR/Cargo.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
PKG_NAME="cursorhome_${VERSION}_${ARCH}"
STAGING="$BUILD_DIR/deb-staging"

echo "==> Building cursorhome (release)..."
cd "$PROJECT_DIR"
cargo build --release

echo "==> Assembling .deb package ($PKG_NAME)..."
rm -rf "$STAGING"
mkdir -p "$STAGING/DEBIAN"
mkdir -p "$STAGING/usr/bin"
mkdir -p "$STAGING/usr/share/applications"
mkdir -p "$STAGING/usr/share/metainfo"
mkdir -p "$STAGING/usr/share/icons/hicolor/scalable/apps"

# Binary
cp "$PROJECT_DIR/target/release/cursorhome" "$STAGING/usr/bin/cursorhome"
chmod 755 "$STAGING/usr/bin/cursorhome"

# Desktop file
cp "$DATA_DIR/cursorhome.desktop" "$STAGING/usr/share/applications/"

# AppStream metainfo
cp "$DATA_DIR/com.cursorhome.linux.metainfo.xml" "$STAGING/usr/share/metainfo/"

# Icon
cp "$DATA_DIR/cursorhome.svg" "$STAGING/usr/share/icons/hicolor/scalable/apps/"

# Installed size (in KB)
INSTALLED_SIZE="$(du -sk "$STAGING" | cut -f1)"

# Control file
cat > "$STAGING/DEBIAN/control" <<EOF
Package: cursorhome
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: libgtk-4-1, libadwaita-1-0, libwayland-client0, libx11-6
Installed-Size: $INSTALLED_SIZE
Maintainer: CursorHome Contributors <cursorhome@example.com>
Homepage: https://github.com/yourusername/CursorHome
Description: Cursor highlighting utility for Linux
 CursorHome helps you locate your cursor when working with large
 screens, multiple displays, or multi-machine setups with Synergy.
 It provides visual highlighting, smooth animations, shake detection,
 and cross-machine cursor tracking.
EOF

# Build .deb
mkdir -p "$BUILD_DIR"
dpkg-deb --build --root-owner-group "$STAGING" "$BUILD_DIR/${PKG_NAME}.deb"

echo "==> Built: $BUILD_DIR/${PKG_NAME}.deb"
echo "    Inspect with: dpkg -I $BUILD_DIR/${PKG_NAME}.deb"
