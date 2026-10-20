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
    echo "🎮 Installing Twixtle v3 (100% Offline Standalone & KOReader Game)..."

    # 1. Standalone NickelMenu application (.adds/twixtle)
    STANDALONE_DIR="$KOBO_MOUNT/.adds/twixtle"
    NM_DIR="$KOBO_MOUNT/.adds/nm"
    echo "  📦 Deploying Standalone NickelMenu app to: $STANDALONE_DIR"
    mkdir -p "$STANDALONE_DIR"
    # Remove deprecated HTML/JS files from legacy web-based twixtle if present
    rm -f "$STANDALONE_DIR/index.html" "$STANDALONE_DIR/app.js" "$STANDALONE_DIR/app.css" "$STANDALONE_DIR/puzzles.js"
    rm -rf "$STANDALONE_DIR/dict" "$STANDALONE_DIR/tools"

    cp "$SCRIPT_DIR/twixtle.koplugin/twixtle.sh" "$STANDALONE_DIR/"
    chmod +x "$STANDALONE_DIR/twixtle.sh"
    cp "$SCRIPT_DIR/twixtle.koplugin/standalone.lua" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/_meta.lua" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/engine.lua" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/dictionary.lua" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/dict_data.lua" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/words.txt" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/puzzles.lua" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/storage.lua" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/twixtle_screen.lua" "$STANDALONE_DIR/"
    cp "$SCRIPT_DIR/twixtle.koplugin/README.md" "$STANDALONE_DIR/"

    # 2. NickelMenu Shortcut (.adds/nm/twixtle)
    echo "  🔘 Configuring NickelMenu direct shortcut in: $NM_DIR/twixtle"
    mkdir -p "$NM_DIR"
    cat << 'EOF' > "$NM_DIR/twixtle"
menu_item :main :Twixtle :cmd_spawn :quiet:exec /mnt/onboard/.adds/twixtle/twixtle.sh
EOF

    # 3. KOReader Plugin (.adds/koreader/plugins/twixtle.koplugin)
    TWIXTLE_DEST="$PLUGINS_DIR/twixtle.koplugin"
    echo "  📖 Deploying KOReader plugin to: $TWIXTLE_DEST"
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
    cp "$SCRIPT_DIR/twixtle.koplugin/README.md" "$TWIXTLE_DEST/"

    if command -v dot_clean >/dev/null 2>&1; then
        dot_clean "$STANDALONE_DIR"
        dot_clean "$NM_DIR"
        dot_clean "$TWIXTLE_DEST"
    fi
    echo "  [✓] Twixtle v3 (Standalone & KOReader) successfully installed."
fi

# Flush all disk buffers
sync

echo ""
echo "================================================================="
echo "✅ All selected plugins successfully installed!"
echo "Please safely eject your Kobo e-reader and launch KOReader."
echo "================================================================="
