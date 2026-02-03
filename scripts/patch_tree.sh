#!/bin/bash

# Configuration
REPO_URL="https://raw.githubusercontent.com/lansing/thingino-sr9700/main"
SRC_C="sr9700.c"
SRC_H="sr9700.h"

# Check if we are in the thingino-firmware root
if [ ! -d "output-stable" ]; then
    echo "ERROR: Please run this from the root of the thingino-firmware directory."
    exit 1
fi

echo ">>> SR9700 Source Patcher"

# Download source files to temp location
TEMP_DIR=$(mktemp -d)
echo "Downloading source files..."
curl -L "$REPO_URL/src/$SRC_C" -o "$TEMP_DIR/$SRC_C"
curl -L "$REPO_URL/src/$SRC_H" -o "$TEMP_DIR/$SRC_H"

# Find valid linux source trees inside output-stable
# Look for directories that contain drivers/net/usb/cdc_ether.c to confirm it's the right place
TARGETS=$(find output-stable -type f -name "cdc_ether.c" | grep "drivers/net/usb")

if [ -z "$TARGETS" ]; then
    echo "ERROR: Could not find Linux kernel source tree."
    echo "Please run a firmware build first (or download cache) to populate the source."
    rm -rf "$TEMP_DIR"
    exit 1
fi

for TARGET_FILE in $TARGETS; do
    TARGET_DIR=$(dirname "$TARGET_FILE")
    echo "Patching: $TARGET_DIR"

    # 1. Copy Source Files
    cp "$TEMP_DIR/$SRC_C" "$TARGET_DIR/"
    cp "$TEMP_DIR/$SRC_H" "$TARGET_DIR/"

    # 2. Patch Makefile
    MAKEFILE="$TARGET_DIR/Makefile"
    if ! grep -q "sr9700.o" "$MAKEFILE"; then
        echo "  - Adding to Makefile..."
        echo "obj-\$(CONFIG_USB_NET_SR9700) += sr9700.o" >> "$MAKEFILE"
    else
        echo "  - Makefile already patched."
    fi

    # 3. Patch Kconfig
    KCONFIG="$TARGET_DIR/Kconfig"
    if ! grep -q "USB_NET_SR9700" "$KCONFIG"; then
        echo "  - Adding to Kconfig..."
        cat <<EOF >> "$KCONFIG"

config USB_NET_SR9700
	tristate "CoreChip SR9700 USB 1.1 Ethernet"
	depends on USB_USBNET
	help
	  SR97004U.
	  Support for the CoreChip SR9700 USB ethernet adapter.
EOF
    else
        echo "  - Kconfig already patched."
    fi

    # 4. Force Rebuild
    # We need to remove the .stamp_built file to force make to reconsider the kernel
    # The path is usually ../../../.stamp_built relative to drivers/net/usb
    STAMP_FILE=$(realpath "$TARGET_DIR/../../../.stamp_built")
    if [ -f "$STAMP_FILE" ]; then
        echo "  - Removing build stamp to force rebuild..."
        rm "$STAMP_FILE"
    fi
done

rm -rf "$TEMP_DIR"
echo ">>> Patching complete."
echo "Now run: ./user-menu.sh"
echo "Go to: Main Menu -> Linux Kernel Configuration -> Device Drivers -> Network device support -> USB Network Adapters"
echo "Enable 'CoreChip SR9700 USB 1.1 Ethernet'"
echo "Then rebuild your firmware."

