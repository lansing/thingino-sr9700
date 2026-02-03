#!/bin/bash

# Configuration
REPO_URL="https://raw.githubusercontent.com/lansing/thingino-sr9700/main"
KO_FILE="sr9700.ko"
DEST_DIR="/lib/modules/$(uname -r)/extra"
MODULES_LOAD="/etc/modules.d/sr9700.conf"

echo ">>> SR9700 Driver Installer for Thingino"

# 1. Create destination directory
if [ ! -d "$DEST_DIR" ]; then
    echo "Creating module directory: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# 2. Download the .ko file
echo "Downloading $KO_FILE..."
# We use curl -k just in case of SSL cert weirdness on old busybox
curl -L -k "$REPO_URL/bin/linux-3.10/$KO_FILE" -o "$DEST_DIR/$KO_FILE"

if [ ! -f "$DEST_DIR/$KO_FILE" ]; then
    echo "ERROR: Download failed."
    exit 1
fi

chmod 644 "$DEST_DIR/$KO_FILE"
echo "Download successful."

# 3. Update dependencies
echo "Updating module dependencies..."
depmod -a
if [ $? -ne 0 ]; then
    echo "Warning: depmod failed. You might need to insmod manually."
fi

# 4. Load the module now
echo "Loading module..."
modprobe sr9700 2>/dev/null || insmod "$DEST_DIR/$KO_FILE"

if lsmod | grep -q "sr9700"; then
    echo "SUCCESS: Module loaded!"
else
    echo "ERROR: Module failed to load. Check dmesg."
    exit 1
fi

# 5. Ensure persistence
# Thingino usually looks in /etc/modules.d/*.conf for modules to load
echo "Configuring boot persistence..."
if [ -d "/etc/modules.d" ]; then
    echo "sr9700" > "$MODULES_LOAD"
    echo "Created $MODULES_LOAD"
else
    # Fallback if modules.d doesn't exist, append to rc.local or similar if needed
    # But usually modules.d is the standard way on Thingino
    echo "Warning: /etc/modules.d not found. You may need to manually add 'modprobe sr9700' to your startup scripts."
fi

echo ">>> Done. Enjoy your cheap ethernet."
