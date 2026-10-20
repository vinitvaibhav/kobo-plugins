#!/bin/sh
# twixtle.sh - Standalone launcher for Twixtle from NickelMenu
# Stops Nickel, launches Twixtle via KOReader's e-ink runtime, and restarts Nickel on exit.

export LC_ALL="en_US.UTF-8"

KOREADER_DIR="/mnt/onboard/.adds/koreader"
TWIXTLE_DIR="/mnt/onboard/.adds/twixtle"

if [ ! -d "$KOREADER_DIR" ]; then
    echo "Error: KOReader not found at $KOREADER_DIR"
    exit 1
fi

cd "$KOREADER_DIR" || exit 1

# Check if Nickel is running
VIA_NICKEL="false"
if pkill -0 nickel 2>/dev/null; then
    VIA_NICKEL="true"
fi

if [ "$VIA_NICKEL" = "true" ]; then
    # Siphon environment from nickel before stopping it
    export $(grep -s -E -e '^(DBUS_SESSION_BUS_ADDRESS|NICKEL_HOME|WIFI_MODULE|LANG|INTERFACE)=' "/proc/$(pidof -s nickel)/environ" 2>/dev/null)
    
    # Flush disk buffers
    sync

    # Stop Nickel software stack so Twixtle gets exclusive touch and framebuffer control
    killall -q -TERM nickel hindenburg sickel fickel strickel fontickel adobehost foxitpdf iink dhcpcd-dbus dhcpcd bluealsa bluetoothd fmon nanoclock.lua 2>/dev/null

    # Wait for Nickel to fully exit
    kill_timeout=0
    while pkill -0 nickel 2>/dev/null; do
        if [ $kill_timeout -ge 16 ]; then
            break
        fi
        usleep 250000
        kill_timeout=$((kill_timeout + 1))
    done
    rm -f /tmp/nickel-hardware-status
fi

# Clear screen with fbink if available
if [ -x "./fbink" ]; then
    ./fbink -q -c -f 2>/dev/null
fi

# Launch Twixtle standalone via KOReader's luajit
./luajit "$TWIXTLE_DIR/standalone.lua"

# On exit, restart Nickel cleanly
if [ "$VIA_NICKEL" = "true" ]; then
    if [ -x "./fbink" ]; then
        ./fbink -q -c -f 2>/dev/null
    fi
    if [ -f "$KOREADER_DIR/nickel.sh" ]; then
        "$KOREADER_DIR/nickel.sh" &
    else
        /usr/local/Kobo/hindenburg &
        LIBC_FATAL_STDERR_=1 /usr/local/Kobo/nickel -platform kobo -skipFontLoad &
    fi
fi
