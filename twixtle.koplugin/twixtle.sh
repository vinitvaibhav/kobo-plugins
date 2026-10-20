#!/bin/sh
# twixtle.sh - Standalone launcher for Twixtle from NickelMenu
# Launches Twixtle directly on Kobo using KOReader's e-ink engine and returns to Nickel on exit.

export LC_ALL="en_US.UTF-8"

KOREADER_DIR="/mnt/onboard/.adds/koreader"
TWIXTLE_DIR="/mnt/onboard/.adds/twixtle"

if [ ! -d "$KOREADER_DIR" ]; then
    echo "Error: KOReader not found at $KOREADER_DIR"
    exit 1
fi

cd "$KOREADER_DIR" || exit 1

# Launch Twixtle directly via KOReader's luajit
./luajit "$TWIXTLE_DIR/standalone.lua"

# When Twixtle exits, restart Nickel smoothly
if [ -f "$KOREADER_DIR/nickel.sh" ]; then
    "$KOREADER_DIR/nickel.sh" &
fi
