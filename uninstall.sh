#!/usr/bin/env bash

set -e

echo "[*] Removing VinMail..."

rm -f /usr/bin/vinmail

rm -rf /usr/lib/vinmail

rm -rf /usr/share/vinmail

rm -f /usr/share/man/man1/vinmail.1

rm -rf /usr/share/licenses/vinmail

if command -v mandb >/dev/null 2>&1; then
    mandb >/dev/null 2>&1 || true
fi

echo "[✓] Removed successfully."
echo "Take Care - It will be here when you need it again."
