#!/bin/bash
# List USB-serial devices with vendor/product/serial info

for dev in /dev/ttyUSB*; do
    [[ -e "$dev" ]] || { echo "No /dev/ttyUSB* devices found"; exit 0; }
    
    echo "=== $dev ==="
    udevadm info --name="$dev" 2>/dev/null | grep -E "(ID_VENDOR_ID|ID_MODEL_ID|ID_SERIAL_SHORT)" | sed 's/^E: /  /'
    echo
done

echo "=== Symlinks ==="
for link in /dev/cisco*; do
    [[ -L "$link" ]] || { echo "No /dev/cisco* symlinks"; break; }
    echo "$link -> $(readlink -f "$link")"
done
