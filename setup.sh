#!/bin/bash
# VinMail v0.3.0 Setup

set -e
VINMAIL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vinmail"

echo "Setting up VinMail v0.2.0..."

mkdir -p "$VINMAIL_DIR/accounts"
install -Dm755 vinmail.sh "$VINMAIL_DIR/vinmail.sh"

sudo mkdir -p /usr/share/vinmail
sudo install -Dm644 usr/share/vinmail/account.conf.template /usr/share/vinmail/account.conf.template
sudo install -Dm644 usr/share/vinmail/mailrc /usr/share/vinmail/mailrc

touch "$VINMAIL_DIR/accounts.list" "$VINMAIL_DIR/.active"
[[ ! -f "$HOME/.mailrc" ]] && cp usr/share/vinmail/mailrc "$HOME/.mailrc"

echo "  ✓ Installed VinMail to $VINMAIL_DIR"
echo ""
echo "Add to your shell config:"
echo "  alias vinmail='$VINMAIL_DIR/vinmail.sh'"
