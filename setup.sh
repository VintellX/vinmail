#!/usr/bin/env bash
set -e

echo "[*] Installing VinMail..."

echo "[*] Installing executable..."
install -Dm755 usr/bin/vinmail /usr/bin/vinmail

echo "[*] Installing modules..."
install -Dm644 usr/lib/vinmail/core.sh     /usr/lib/vinmail/core.sh
install -Dm644 usr/lib/vinmail/ui.sh       /usr/lib/vinmail/ui.sh
install -Dm644 usr/lib/vinmail/accounts.sh /usr/lib/vinmail/accounts.sh
install -Dm644 usr/lib/vinmail/compose.sh  /usr/lib/vinmail/compose.sh

echo "[*] Installing templates and configs..."
install -Dm644 usr/share/vinmail/account.conf.template \
  /usr/share/vinmail/account.conf.template

install -Dm644 usr/share/vinmail/mailrc \
  /usr/share/vinmail/mailrc

echo "[*] Installing man page..."
install -Dm644 usr/share/man/man1/vinmail.1 \
  /usr/share/man/man1/vinmail.1

echo "[*] Installing license..."
install -Dm644 LICENSE \
  /usr/share/licenses/vinmail/LICENSE

echo "[✓] Installation complete."
echo "Run: vinmail"
echo "For usage details: man vinmail"
