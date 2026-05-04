#!/usr/bin/env bash
set -e

echo "[*] Uninstalling VinMail (macOS)..."

PREFIX="${PREFIX:-/usr/local}"

if [[ -d "/opt/homebrew" ]]; then
  PREFIX="/opt/homebrew"
fi

echo "[*] Using prefix: $PREFIX"

rm -f "$PREFIX/bin/vinmail"
rm -rf "$PREFIX/lib/vinmail"
rm -rf "$PREFIX/share/vinmail"
rm -f "$PREFIX/share/man/man1/vinmail.1"
rm -rf "$PREFIX/share/licenses/vinmail"

echo "[✓] VinMail removed successfully."
