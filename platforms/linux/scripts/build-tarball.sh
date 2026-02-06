#!/usr/bin/env bash
#
# build-tarball.sh — Build a .tar.gz distribution with install script
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DATA_DIR="$PROJECT_DIR/data"

# Read version from Cargo.toml
VERSION="$(grep '^version' "$PROJECT_DIR/Cargo.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')"
ARCH="$(uname -m)"
TARBALL_NAME="cursorhome-${VERSION}-linux-${ARCH}"
STAGING="$BUILD_DIR/tarball-staging/$TARBALL_NAME"

echo "==> Building cursorhome (release)..."
cd "$PROJECT_DIR"
cargo build --release

echo "==> Assembling tarball ($TARBALL_NAME)..."
rm -rf "$BUILD_DIR/tarball-staging"
mkdir -p "$STAGING"

# Binary
cp "$PROJECT_DIR/target/release/cursorhome" "$STAGING/cursorhome"
chmod 755 "$STAGING/cursorhome"

# Data files
cp "$DATA_DIR/cursorhome.desktop" "$STAGING/"
cp "$DATA_DIR/com.cursorhome.linux.metainfo.xml" "$STAGING/"
cp "$DATA_DIR/cursorhome.svg" "$STAGING/"

# Install script
cat > "$STAGING/install.sh" <<'INSTALL_EOF'
#!/usr/bin/env bash
#
# install.sh — Install or uninstall CursorHome
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MODE="system"
UNINSTALL=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --user        Install to ~/.local/ (no root required)
  --uninstall   Remove CursorHome
  -h, --help    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)      MODE="user"; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ "$MODE" == "user" ]]; then
    PREFIX="$HOME/.local"
    BIN_DIR="$PREFIX/bin"
    APPS_DIR="$PREFIX/share/applications"
    META_DIR="$PREFIX/share/metainfo"
    ICON_DIR="$PREFIX/share/icons/hicolor/scalable/apps"
else
    PREFIX="/usr/local"
    BIN_DIR="$PREFIX/bin"
    APPS_DIR="/usr/share/applications"
    META_DIR="/usr/share/metainfo"
    ICON_DIR="/usr/share/icons/hicolor/scalable/apps"
fi

if $UNINSTALL; then
    echo "==> Uninstalling CursorHome ($MODE)..."
    rm -f "$BIN_DIR/cursorhome"
    rm -f "$APPS_DIR/cursorhome.desktop"
    rm -f "$META_DIR/com.cursorhome.linux.metainfo.xml"
    rm -f "$ICON_DIR/cursorhome.svg"
    echo "==> CursorHome uninstalled"
    exit 0
fi

echo "==> Installing CursorHome ($MODE)..."
mkdir -p "$BIN_DIR" "$APPS_DIR" "$META_DIR" "$ICON_DIR"

cp "$SCRIPT_DIR/cursorhome" "$BIN_DIR/cursorhome"
chmod 755 "$BIN_DIR/cursorhome"

cp "$SCRIPT_DIR/cursorhome.desktop" "$APPS_DIR/"
cp "$SCRIPT_DIR/com.cursorhome.linux.metainfo.xml" "$META_DIR/"
cp "$SCRIPT_DIR/cursorhome.svg" "$ICON_DIR/"

echo "==> CursorHome installed to $PREFIX"
if [[ "$MODE" == "user" ]]; then
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^$HOME/.local/bin$"; then
        echo "    Note: Add ~/.local/bin to your PATH if not already present"
    fi
fi
echo "    Run with: cursorhome"
INSTALL_EOF
chmod 755 "$STAGING/install.sh"

# Create tarball
mkdir -p "$BUILD_DIR"
tar -czf "$BUILD_DIR/${TARBALL_NAME}.tar.gz" \
    -C "$BUILD_DIR/tarball-staging" \
    "$TARBALL_NAME"

# Cleanup staging
rm -rf "$BUILD_DIR/tarball-staging"

echo "==> Built: $BUILD_DIR/${TARBALL_NAME}.tar.gz"
echo "    Extract with: tar xzf ${TARBALL_NAME}.tar.gz"
echo "    Install with: cd $TARBALL_NAME && ./install.sh --user"
