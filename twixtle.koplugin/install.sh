#!/usr/bin/env bash
# install.sh - Installs Twixtle onto a connected Kobo e-reader (Clara BW & all models)
# Installs both:
#   1. Standalone NickelMenu launcher in .adds/twixtle (accessible directly from home screen)
#   2. Native KOReader plugin in .adds/koreader/plugins/twixtle.koplugin
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
    echo "Please connect your Kobo via USB, tap 'Connect' on screen, then run:"
    echo "  ./install.sh [path_to_kobo_mount]"
    echo ""
    echo "Examples:"
    echo "  macOS: ./install.sh /Volumes/KOBOeReader"
    echo "  Linux: ./install.sh /media/$USER/KOBOeReader"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STANDALONE_DIR="$KOBO_MOUNT/.adds/twixtle"
KOPLUGIN_DIR="$KOBO_MOUNT/.adds/koreader/plugins/twixtle.koplugin"
NM_DIR="$KOBO_MOUNT/.adds/nm"

echo "================================================================="
echo " Installing Twixtle v3 (E-Ink Minimal UI, 550 Verified Levels)"
echo " Kobo Mount: $KOBO_MOUNT"
echo "================================================================="

# 1. Install Standalone App for NickelMenu
echo "📦 Installing Standalone NickelMenu application to: $STANDALONE_DIR"
mkdir -p "$STANDALONE_DIR"
cp "$SCRIPT_DIR/twixtle.sh" "$STANDALONE_DIR/"
chmod +x "$STANDALONE_DIR/twixtle.sh"
cp "$SCRIPT_DIR/standalone.lua" "$STANDALONE_DIR/"
cp "$SCRIPT_DIR/_meta.lua" "$STANDALONE_DIR/"
cp "$SCRIPT_DIR/engine.lua" "$STANDALONE_DIR/"
cp "$SCRIPT_DIR/dictionary.lua" "$STANDALONE_DIR/"
cp "$SCRIPT_DIR/dict_data.lua" "$STANDALONE_DIR/"
cp "$SCRIPT_DIR/words.txt" "$STANDALONE_DIR/"
cp "$SCRIPT_DIR/puzzles.lua" "$STANDALONE_DIR/"
cp "$SCRIPT_DIR/storage.lua" "$STANDALONE_DIR/"
cp "$SCRIPT_DIR/twixtle_screen.lua" "$STANDALONE_DIR/"

# 2. Install NickelMenu Shortcut
echo "🔘 Configuring NickelMenu direct shortcut in: $NM_DIR/twixtle"
mkdir -p "$NM_DIR"
cat << 'EOF' > "$NM_DIR/twixtle"
menu_item :main :Twixtle :cmd_spawn :quiet:exec /mnt/onboard/.adds/twixtle/twixtle.sh
EOF

# 3. Install KOReader Plugin
echo "📖 Installing KOReader plugin to: $KOPLUGIN_DIR"
mkdir -p "$KOPLUGIN_DIR"
cp "$SCRIPT_DIR/_meta.lua" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/main.lua" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/engine.lua" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/dictionary.lua" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/dict_data.lua" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/words.txt" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/puzzles.lua" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/storage.lua" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/twixtle_screen.lua" "$KOPLUGIN_DIR/"
cp "$SCRIPT_DIR/README.md" "$KOPLUGIN_DIR/"

# Clean macOS metadata files if on macOS
if command -v dot_clean >/dev/null 2>&1; then
    dot_clean "$STANDALONE_DIR"
    dot_clean "$KOPLUGIN_DIR"
    dot_clean "$NM_DIR"
fi

sync

echo ""
echo "================================================================="
echo "✅ Twixtle v3 successfully installed!"
echo ""
echo "How to launch:"
echo " 1. Directly from Kobo Home Screen:"
echo "    Tap 'NickelMenu' ➔ 'Twixtle' (opens instantly without KOReader)"
echo " 2. Inside KOReader:"
echo "    Tap top menu ➔ Tools ➔ More tools ➔ Twixtle"
echo "================================================================="
