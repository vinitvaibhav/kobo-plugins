#!/usr/bin/env bash
# install.sh - Universal installer for kobo-plugins
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
TARGET="all"
CUSTOM_MOUNT=""

for arg in "$@"; do
    if [ "$arg" = "all" ] || [ "$arg" = "twixtle" ] || [ "$arg" = "kobostatsmerge" ]; then
        TARGET="$arg"
    elif [ -d "$arg" ]; then
        CUSTOM_MOUNT="$arg"
    fi
done

# Detect Kobo mount point
KOBO_MOUNT=""
if [ -n "$CUSTOM_MOUNT" ]; then
    KOBO_MOUNT="$CUSTOM_MOUNT"
elif [ -d "/Volumes/KOBOeReader" ]; then
    KOBO_MOUNT="/Volumes/KOBOeReader"
elif [ -d "/media/$USER/KOBOeReader" ]; then
    KOBO_MOUNT="/media/$USER/KOBOeReader"
elif [ -d "/run/media/$USER/KOBOeReader" ]; then
    KOBO_MOUNT="/run/media/$USER/KOBOeReader"
fi

if [ -z "$KOBO_MOUNT" ]; then
    echo "❌ Error: Connected Kobo e-reader mount point not detected."
    echo ""
    echo "Usage: ./install.sh [all|twixtle|kobostatsmerge] [path_to_kobo_mount]"
    echo ""
    echo "Examples:"
    echo "  ./install.sh                      # Installs all plugins to /Volumes/KOBOeReader"
    echo "  ./install.sh twixtle              # Installs only Twixtle KOReader plugin"
    echo "  ./install.sh kobostatsmerge       # Installs only KoboStatsMerge plugin"
    echo "  ./install.sh all /Volumes/KOBOeReader"
    exit 1
fi

PLUGINS_DIR="$KOBO_MOUNT/.adds/koreader/plugins"
mkdir -p "$PLUGINS_DIR"

echo "================================================================="
echo " Kobo Plugins Universal Installer"
echo " Target:     $TARGET"
echo " Kobo Mount: $KOBO_MOUNT"
echo " Plugins:    $PLUGINS_DIR"
echo "================================================================="

# Install kobostatsmerge if selected
if [ "$TARGET" = "all" ] || [ "$TARGET" = "kobostatsmerge" ]; then
    echo ""
    echo "📦 Installing kobostatsmerge.koplugin..."
    KSM_DEST="$PLUGINS_DIR/kobostatsmerge.koplugin"
    mkdir -p "$KSM_DEST"
    cp "$SCRIPT_DIR/kobostatsmerge.koplugin/_meta.lua" "$KSM_DEST/"
    cp "$SCRIPT_DIR/kobostatsmerge.koplugin/main.lua" "$KSM_DEST/"
    cp "$SCRIPT_DIR/kobostatsmerge.koplugin/qvariant.lua" "$KSM_DEST/"
    cp "$SCRIPT_DIR/kobostatsmerge.koplugin/sync_engine.lua" "$KSM_DEST/"
    if command -v dot_clean >/dev/null 2>&1; then
        dot_clean "$KSM_DEST"
    fi
    echo "  [✓] kobostatsmerge.koplugin installed."
fi

# Install twixtle if selected
if [ "$TARGET" = "all" ] || [ "$TARGET" = "twixtle" ]; then
    echo ""
    echo "🎮 Installing twixtle.koplugin (100% Offline KOReader Game)..."
    TWIXTLE_DEST="$PLUGINS_DIR/twixtle.koplugin"
    mkdir -p "$TWIXTLE_DEST"
    cp "$SCRIPT_DIR/twixtle.koplugin/_meta.lua" "$TWIXTLE_DEST/"
    cp "$SCRIPT_DIR/twixtle.koplugin/main.lua" "$TWIXTLE_DEST/"
    cp "$SCRIPT_DIR/twixtle.koplugin/engine.lua" "$TWIXTLE_DEST/"
    cp "$SCRIPT_DIR/twixtle.koplugin/dictionary.lua" "$TWIXTLE_DEST/"
    cp "$SCRIPT_DIR/twixtle.koplugin/dict_data.lua" "$TWIXTLE_DEST/"
    cp "$SCRIPT_DIR/twixtle.koplugin/words.txt" "$TWIXTLE_DEST/"
    cp "$SCRIPT_DIR/twixtle.koplugin/puzzles.lua" "$TWIXTLE_DEST/"
    cp "$SCRIPT_DIR/twixtle.koplugin/storage.lua" "$TWIXTLE_DEST/"
    cp "$SCRIPT_DIR/twixtle.koplugin/twixtle_screen.lua" "$TWIXTLE_DEST/"

    # Remove deprecated buggy browser version if present
    if [ -d "$KOBO_MOUNT/.adds/twixtle" ]; then
        echo "  🧹 Removing deprecated browser-based twixtle web app from .adds/twixtle..."
        rm -rf "$KOBO_MOUNT/.adds/twixtle"
    fi
    if [ -f "$KOBO_MOUNT/.adds/nm/twixtle" ]; then
        echo "  🧹 Removing legacy NickelMenu browser shortcut..."
        rm -f "$KOBO_MOUNT/.adds/nm/twixtle"
    fi

    if command -v dot_clean >/dev/null 2>&1; then
        dot_clean "$TWIXTLE_DEST"
    fi
    echo "  [✓] twixtle.koplugin installed."
fi

# Flush all disk buffers
sync

echo ""
echo "================================================================="
echo "✅ All selected plugins successfully installed!"
echo "Please safely eject your Kobo e-reader and launch KOReader."
echo "================================================================="
