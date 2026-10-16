#!/bin/bash
# ==============================================================================
# Twixtle - 1-Click Installer for Kobo eReader (NickelMenu Integration)
# ==============================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}====================================================${NC}"
echo -e "${BOLD}${BLUE}        Twixtle for Kobo eReader - Installer       ${NC}"
echo -e "${BOLD}${BLUE}====================================================${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Detect Kobo Mount Point
KOBO_ROOT=""

# macOS common mount paths
if [ -d "/Volumes/KOBOeReader" ]; then
    KOBO_ROOT="/Volumes/KOBOeReader"
# Linux common mount paths
elif [ -d "/media/$USER/KOBOeReader" ]; then
    KOBO_ROOT="/media/$USER/KOBOeReader"
elif [ -d "/run/media/$USER/KOBOeReader" ]; then
    KOBO_ROOT="/run/media/$USER/KOBOeReader"
else
    # Check any mounted volume with .kobo directory
    for mount in /Volumes/* /media/*/* /run/media/*/*; do
        if [ -d "$mount/.kobo" ]; then
            KOBO_ROOT="$mount"
            break
        fi
    done
fi

if [ -z "$KOBO_ROOT" ]; then
    echo -e "${RED}[!] Error: No mounted Kobo eReader detected.${NC}"
    echo -e "${YELLOW}Please connect your Kobo device via USB and tap 'Connect' on the screen.${NC}"
    echo -e "Alternatively, you can provide the mount path as an argument:"
    echo -e "  $0 /path/to/kobo"
    exit 1
fi

echo -e "${GREEN}[✓] Detected Kobo mounted at: ${BOLD}${KOBO_ROOT}${NC}"

# Check for .kobo directory
if [ ! -d "${KOBO_ROOT}/.kobo" ]; then
    echo -e "${RED}[!] Error: Directory ${KOBO_ROOT} does not appear to be a valid Kobo filesystem (missing .kobo).${NC}"
    exit 1
fi

# 2. Check for NickelMenu
NM_DIR="${KOBO_ROOT}/.adds/nm"
if [ ! -d "$NM_DIR" ]; then
    echo -e "${YELLOW}[!] Notice: NickelMenu directory (.adds/nm) not found.${NC}"
    echo -e "Creating ${NM_DIR} directory..."
    mkdir -p "$NM_DIR"
fi

# 3. Create Target Directory: .adds/twixtle
TARGET_DIR="${KOBO_ROOT}/.adds/twixtle"
echo -e "${BLUE}[+] Installing Twixtle to ${TARGET_DIR}...${NC}"
mkdir -p "${TARGET_DIR}/dict"

# Copy web files
cp -v "${SCRIPT_DIR}/index.html" "${TARGET_DIR}/"
cp -v "${SCRIPT_DIR}/app.css" "${TARGET_DIR}/"
cp -v "${SCRIPT_DIR}/app.js" "${TARGET_DIR}/"
cp -v "${SCRIPT_DIR}/puzzles.js" "${TARGET_DIR}/"
cp -v "${SCRIPT_DIR}/dict/data.js" "${TARGET_DIR}/dict/"

echo -e "${GREEN}[✓] Twixtle files successfully copied.${NC}"

# 4. Configure NickelMenu Item
NM_CONFIG="${NM_DIR}/config"
NM_TWIXTLE_FILE="${NM_DIR}/twixtle"
NM_ENTRY="menu_item :main :Twixtle :nickel_browser :modal :file:///mnt/onboard/.adds/twixtle/index.html"

# Add standalone NM config file for modularity
echo "$NM_ENTRY" > "$NM_TWIXTLE_FILE"
echo -e "${GREEN}[✓] Created NickelMenu item in: ${NM_TWIXTLE_FILE}${NC}"

# Also ensure it's in .adds/nm/config if user uses a single config file
if [ -f "$NM_CONFIG" ]; then
    if grep -q "file:///mnt/onboard/.adds/twixtle" "$NM_CONFIG"; then
        echo -e "${BLUE}[*] NickelMenu item already present in ${NM_CONFIG}${NC}"
    else
        echo -e "${BLUE}[+] Backing up ${NM_CONFIG} to ${NM_CONFIG}.bak...${NC}"
        cp "$NM_CONFIG" "${NM_CONFIG}.bak"
        echo "" >> "$NM_CONFIG"
        echo "# Twixtle Word Game" >> "$NM_CONFIG"
        echo "$NM_ENTRY" >> "$NM_CONFIG"
        echo -e "${GREEN}[✓] Appended Twixtle item to ${NM_CONFIG}${NC}"
    fi
fi

# 5. Flush Disk Buffers
echo -e "${BLUE}[+] Syncing filesystem buffers...${NC}"
sync

echo -e "\n${BOLD}${GREEN}====================================================${NC}"
echo -e "${BOLD}${GREEN}        Installation Completed Successfully!       ${NC}"
echo -e "${BOLD}${GREEN}====================================================${NC}"
echo -e "${BOLD}Next steps:${NC}"
echo -e " 1. Safely eject the Kobo eReader from your computer."
echo -e " 2. Wait for Kobo to process changes (NickelMenu will automatically reload)."
echo -e " 3. Tap '${BOLD}NickelMenu${NC}' on the Kobo Home screen."
echo -e " 4. Tap '${BOLD}Twixtle${NC}' to play!"
echo ""
