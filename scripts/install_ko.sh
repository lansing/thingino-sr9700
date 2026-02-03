#!/bin/sh

# Configuration
REPO_URL="https://raw.githubusercontent.com/lansing/thingino-sr9700/refs/heads/master/bin/linux-3.10.14__isvp_swan_1.0__"
KO_FILE="sr9700.ko"
DEST_DIR="/lib/modules/$(uname -r)/extra"
MODULES_LOAD="/etc/modules.d/sr9700.conf"

echo ">>> SR9700 Driver Installer for Thingino (curl version)"

# 0. Safety Check: Ensure Root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: You must run this script as root."
    exit 1
fi

# 1. Create destination directory
if [ ! -d "$DEST_DIR" ]; then
    echo "Creating module directory: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# 2. Download the .ko file using curl
TARGET_URL="$REPO_URL/$KO_FILE"
OUTPUT_FILE="$DEST_DIR/$KO_FILE"

echo "Downloading $KO_FILE via curl from $TARGET_URL"

# curl arguments used:
# -L : Follow redirects (critical for GitHub raw links)
# -k : Insecure mode (skip SSL verification, essential on older embedded devices)
# -o : Write output to file
curl -L -k -o "$OUTPUT_FILE" "$TARGET_URL"

# Verify download
if [ ! -s "$OUTPUT_FILE" ]; then
    echo "ERROR: Download failed. File is empty or missing."
    # clean up empty file if it exists
    if [ -f "$OUTPUT_FILE" ]; then rm "$OUTPUT_FILE"; fi
    exit 1
fi

chmod 644 "$OUTPUT_FILE"
echo "Download successful."

# 3. Update dependencies
echo "Updating module dependencies..."
# We try depmod, but don't exit on failure as read-only systems might block it
depmod -a >/dev/null 2>&1

# 4. Load the module now
echo "Loading module..."

# Step 1: Try polite standard load
if modprobe sr9700 2>/dev/null; then
    echo "SUCCESS: Loaded via standard modprobe."
# Step 2: Try forcing modprobe (ignores version errors)
elif modprobe -f sr9700 2>/dev/null; then
    echo "SUCCESS: Loaded via modprobe -f (forced)."
# Step 3: Try forcing insmod (The brute force method)
# This explicitly ignores the 'vermagic' string mismatch
elif insmod -f "$OUTPUT_FILE" 2>/dev/null; then
    echo "SUCCESS: Loaded via insmod -f (forced)."
fi


# Check if it actually loaded
if lsmod | grep -q "^sr9700"; then
    echo "SUCCESS: Module loaded!"
else
    echo "ERROR: Module failed to load. Run 'dmesg' to see why."
    exit 1
fi

# 5. Ensure persistence
echo "Configuring boot persistence..."
if [ -d "/etc/modules.d" ]; then
    echo "sr9700" > "$MODULES_LOAD"
    echo "Created $MODULES_LOAD"
else
    echo "Warning: /etc/modules.d not found."
    echo "You may need to manually add 'modprobe sr9700' to your startup scripts."
fi

echo ">>> Done. Enjoy your ethernet."
