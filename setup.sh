#!/bin/bash

VinMailDir="$HOME/.vinmail"
mailrc="$HOME/.mailrc"

mkdir -p $VinMailDir
cp VinMails.sh "$VinMailDir/VinMails.sh"
chmod +x "$VinMailDir/VinMails.sh"

cp Mail1 "$VinMailDir/Mail1"
cp Mail1 "$VinMailDir/Mail2"
cp Mail1 "$VinMailDir/Mail3"

cp mailrc $mailrc
