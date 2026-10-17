#!/usr/bin/env bash
# install.sh - Installs twixtle.koplugin onto a connected Kobo e-reader
set -e

# Detect Kobo mount point
KOBO_MOUNT=""
if [ -d "/Volumes/KOBOeReader" ]; then
    KOBO_MOUNT="/Volumes/KOBOeReader"
elif [ -d "/media/$USER/KOBOeReader" ]; then
    KOBO_MOUNT="/media/$USER/KOBOeReader"
elif [ -d "/run/media/$USER/KOBOeReader" ]; then
    KOBO_MOUNT="/run/media/$USER/KOBOeReader"
elif [ -n "$1" ] && [ -d "$1" ]; then
    KOBO_MOUNT="$1"
fi

if [ -z "$KOBO_MOUNT" ]; then
    echo "❌ Error: Connected Kobo e-reader mount point not detected."
    echo ""
    echo "Please connect your Kobo via USB, tap 'Connect', then run:"
    echo "  ./install.sh [path_to_kobo_mount]"
    echo ""
    echo "Examples:"
    echo "  macOS: ./install.sh /Volumes/KOBOeReader"
    echo "  Linux: ./install.sh /media/$USER/KOBOeReader"
    exit 1
fi

DEST_DIR="$KOBO_MOUNT/.adds/koreader/plugins/twixtle.koplugin"

echo "================================================================="
echo " Installing Twixtle KOReader Plugin (Native Lua, 100% Offline)"
echo " Destination: $DEST_DIR"
echo "================================================================="

mkdir -p "$DEST_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy plugin files
cp "$SCRIPT_DIR/_meta.lua" "$DEST_DIR/"
cp "$SCRIPT_DIR/main.lua" "$DEST_DIR/"
cp "$SCRIPT_DIR/engine.lua" "$DEST_DIR/"
cp "$SCRIPT_DIR/dictionary.lua" "$DEST_DIR/"
cp "$SCRIPT_DIR/dict_data.lua" "$DEST_DIR/"
cp "$SCRIPT_DIR/words.txt" "$DEST_DIR/"
cp "$SCRIPT_DIR/puzzles.lua" "$DEST_DIR/"
cp "$SCRIPT_DIR/storage.lua" "$DEST_DIR/"
cp "$SCRIPT_DIR/twixtle_screen.lua" "$DEST_DIR/"

# Remove legacy broken web-app files if present to prevent browser confusion
if [ -d "$KOBO_MOUNT/.adds/twixtle" ]; then
    echo "🧹 Removing deprecated browser-based twixtle web app from .adds/twixtle..."
    rm -rf "$KOBO_MOUNT/.adds/twixtle"
fi
if [ -f "$KOBO_MOUNT/.adds/nm/twixtle" ]; then
    echo "🧹 Removing legacy NickelMenu browser shortcut..."
    rm -f "$KOBO_MOUNT/.adds/nm/twixtle"
fi

# Clean macOS metadata files if on macOS
if command -v dot_clean >/dev/null 2>&1; then
    dot_clean "$DEST_DIR"
fi

sync

echo ""
echo "✅ Twixtle KOReader Plugin installed successfully!"
echo ""
echo "Next steps:"
echo " 1. Safely eject your Kobo e-reader."
echo " 2. Open KOReader on your Kobo."
echo " 3. Tap top menu ➔ Tools (Search/Gear icon) ➔ More tools ➔ Twixtle"
echo " 4. Enjoy 550 offline levels!"
echo "================================================================="
