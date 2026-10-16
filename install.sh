#!/usr/bin/env bash
# install.sh - Installs kobostatsmerge.koplugin onto a connected Kobo e-reader

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
    echo "Usage: ./install.sh [path_to_kobo_mount]"
    echo "Example (macOS): ./install.sh /Volumes/KOBOeReader"
    echo "Example (Linux): ./install.sh /media/$USER/KOBOeReader"
    exit 1
fi

DEST_DIR="$KOBO_MOUNT/.adds/koreader/plugins/kobostatsmerge.koplugin"

echo "================================================================="
echo " Installing kobostatsmerge.koplugin to:"
echo "   $DEST_DIR"
echo "================================================================="

mkdir -p "$DEST_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$SCRIPT_DIR/kobostatsmerge.koplugin"

cp "$PLUGIN_SRC/_meta.lua" "$DEST_DIR/"
cp "$PLUGIN_SRC/main.lua" "$DEST_DIR/"
cp "$PLUGIN_SRC/qvariant.lua" "$DEST_DIR/"
cp "$PLUGIN_SRC/sync_engine.lua" "$DEST_DIR/"

# Clean macOS metadata files if on macOS
if command -v dot_clean >/dev/null 2>&1; then
    dot_clean "$DEST_DIR"
fi

sync

echo ""
echo "✅ Installation successful!"
echo "Please safely eject your Kobo e-reader and open KOReader."
