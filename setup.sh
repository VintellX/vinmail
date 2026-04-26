#!/bin/bash

VINMAIL_DIR="$HOME/.vinmail"
mkdir -p "$VINMAIL_DIR"

cp vinmail.sh "$VINMAIL_DIR/vinmail.sh"
chmod +x "$VINMAIL_DIR/vinmail.sh"

cp Mail.template "$VINMAIL_DIR/Mail1"
cp Mail.template "$VINMAIL_DIR/Mail2"
cp Mail.template "$VINMAIL_DIR/Mail3"

echo "VinMail installed to $VINMAIL_DIR"
echo ""
echo "Edit your account configs:"
echo "  $VINMAIL_DIR/Mail1"
echo "  $VINMAIL_DIR/Mail2"
echo "  $VINMAIL_DIR/Mail3"
echo ""
echo "Then edit vinmail.sh and set your email addresses in the mailos=() array."
echo ""
echo "Add alias to your shell:"
echo "  echo \"alias vinmail='$VINMAIL_DIR/vinmail.sh'\" >> ~/.bashrc"
mailrc="$HOME/.mailrc"
