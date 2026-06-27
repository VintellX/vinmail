#!/usr/bin/env bash
set -e

echo "[*] Installing VinMail (macOS)..."

PREFIX="${PREFIX:-/usr/local}"

if [[ -d "/opt/homebrew" ]]; then
  PREFIX="/opt/homebrew"
fi

BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/lib/vinmail"
SHARE_DIR="$PREFIX/share/vinmail"
MAN_DIR="$PREFIX/share/man/man1"
LICENSE_DIR="$PREFIX/share/licenses/vinmail"

echo "[*] Using prefix: $PREFIX"

mkdir -p "$BIN_DIR" "$LIB_DIR" "$SHARE_DIR" "$MAN_DIR" "$LICENSE_DIR"

echo "[*] Installing executable..."
install -m755 usr/bin/vinmail "$BIN_DIR/vinmail"

echo "[*] Fixing runtime paths..."
sed -i '' \
  's|LIB="/usr/lib/vinmail"|LIB="$(cd "$(dirname "$0")/../lib/vinmail" && pwd)"|' \
  "$BIN_DIR/vinmail"

sed -i '' \
  's|TEMPLATE_DIR="/usr/share/vinmail"|TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../share/vinmail" && pwd)"|' \
  usr/lib/vinmail/core.sh

echo "[*] Installing modules..."
install -m644 usr/lib/vinmail/*.sh "$LIB_DIR/"

echo "[*] Installing templates..."
install -m644 usr/share/vinmail/* "$SHARE_DIR/"

echo "[*] Installing man page..."
install -m644 usr/share/man/man1/vinmail.1 "$MAN_DIR/"

echo "[*] Installing license..."
install -m644 LICENSE "$LICENSE_DIR/"

echo "[✓] Installation complete!"
echo ""
echo "Run: vinmail"
echo "Man page: man vinmail"
