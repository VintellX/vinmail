#!/bin/bash
# VinMail v0.2.0 Setup

VINMAIL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vinmail"

echo "Setting up VinMail v0.2.0..."

mkdir -p "$VINMAIL_DIR/accounts"

install -Dm755 vinmail.sh "$VINMAIL_DIR/vinmail.sh"
install -Dm644 usr/share/vinmail/account.conf.template \
    "/usr/share/vinmail/account.conf.template" 2>/dev/null \
    || mkdir -p "$VINMAIL_DIR/share" && cp usr/share/vinmail/account.conf.template \
    "$VINMAIL_DIR/share/account.conf.template"

[[ ! -f "$HOME/.mailrc" ]] && cp usr/share/vinmail/mailrc "$HOME/.mailrc"

touch "$VINMAIL_DIR/accounts.list"
touch "$VINMAIL_DIR/.active"

echo "  ✓ Installed to $VINMAIL_DIR"
echo ""
echo "Add alias to your shell (~/.bashrc or ~/.zshrc):"
echo "  alias vinmail='$VINMAIL_DIR/vinmail.sh'"
