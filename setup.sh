#!/usr/bin/env bash
set -e

echo "[*] Installing VinMail..."

install -Dm755 usr/bin/vinmail /usr/bin/vinmail

install -Dm644 usr/lib/vinmail/core.sh     /usr/lib/vinmail/core.sh
install -Dm644 usr/lib/vinmail/ui.sh       /usr/lib/vinmail/ui.sh
install -Dm644 usr/lib/vinmail/accounts.sh /usr/lib/vinmail/accounts.sh
install -Dm644 usr/lib/vinmail/compose.sh  /usr/lib/vinmail/compose.sh

install -Dm644 usr/share/vinmail/account.conf.template \
  /usr/share/vinmail/account.conf.template

install -Dm644 usr/share/vinmail/mailrc \
  /usr/share/vinmail/mailrc

install -Dm644 usr/share/man/man1/vinmail.1 \
  /usr/share/man/man1/vinmail.1

echo "[✓] Installation complete."
echo "Run: vinmail"
