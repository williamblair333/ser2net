#!/bin/bash
# udev_mapper.sh - Generate udev rules for USB-serial adapters
#
# Usage:
#   ./udev_mapper.sh              Auto-scan, serial-based rules (preferred)
#   ./udev_mapper.sh -k           KERNELS mode for all adapters (path-based)
#   ./udev_mapper.sh -k ttyUSB2   KERNELS mode for specific device
#
# Output goes to stdout. Review before applying:
#   ./udev_mapper.sh >> z21_persistent-local.rules

set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DEVICE]

Generate udev rules for USB-serial adapters.

Options:
  -k, --kernels    Use KERNELS (physical USB path) instead of serial number
                   Required for adapters without serial numbers (CH340/CH341)
                   WARNING: Rules break if adapter moves to different USB port
  -h, --help       Show this help

Arguments:
  DEVICE           Specific device (e.g., ttyUSB2). Default: scan all /dev/ttyUSB*

Examples:
  $(basename "$0")                 # Auto-scan, serial-based rules
  $(basename "$0") -k              # Auto-scan, KERNELS mode
  $(basename "$0") -k ttyUSB2      # KERNELS mode for specific device

Output:
  Rules are printed to stdout. Review, then append to rules file:
    $(basename "$0") >> z21_persistent-local.rules
    sudo ./udev_set.sh
EOF
    exit 0
}

# Parse arguments
KERNELS_MODE=false
TARGET_DEVICE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--kernels)
            KERNELS_MODE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            TARGET_DEVICE="$1"
            shift
            ;;
    esac
done

# Build device list
if [[ -n "$TARGET_DEVICE" ]]; then
    # Specific device
    if [[ "$TARGET_DEVICE" != /dev/* ]]; then
        TARGET_DEVICE="/dev/$TARGET_DEVICE"
    fi
    if [[ ! -e "$TARGET_DEVICE" ]]; then
        echo "Error: Device $TARGET_DEVICE not found" >&2
        exit 1
    fi
    devices=("$TARGET_DEVICE")
else
    # Scan all
    devices=(/dev/ttyUSB*)
    if [[ ! -e "${devices[0]}" ]]; then
        echo "# No /dev/ttyUSB* devices found" >&2
        exit 1
    fi
fi

# Header
echo "# Generated udev rules for USB-serial adapters"
echo "# $(date)"
if $KERNELS_MODE; then
    echo "# Mode: KERNELS (physical USB path)"
    echo "# WARNING: Rules will break if adapter is moved to a different USB port"
else
    echo "# Mode: Serial-based (preferred)"
fi
echo

# Generate rules
count=0
for dev in "${devices[@]}"; do
    [[ -e "$dev" ]] || continue
    
    devname=$(basename "$dev")
    
    # Get device info
    vendor=$(udevadm info --name="$dev" 2>/dev/null | grep "ID_VENDOR_ID=" | cut -d= -f2)
    model=$(udevadm info --name="$dev" 2>/dev/null | grep "ID_MODEL_ID=" | cut -d= -f2)
    serial=$(udevadm info --name="$dev" 2>/dev/null | grep "ID_SERIAL_SHORT=" | cut -d= -f2)
    
    if [[ -z "$vendor" || -z "$model" ]]; then
        echo "# WARN: $dev - could not read vendor/model, skipping" >&2
        continue
    fi
    
    echo "# $dev"
    echo "# Vendor: $vendor  Product: $model  Serial: ${serial:-NONE}"
    
    if $KERNELS_MODE; then
        # KERNELS mode - use physical USB path
        syspath=$(udevadm info --name="$dev" --query=path 2>/dev/null)
        if [[ -z "$syspath" ]]; then
            echo "# ERROR: Could not get syspath for $dev" >&2
            continue
        fi
        
        # Get KERNELS value from udevadm attribute walk
        kernels=$(udevadm info --attribute-walk --path="$syspath" 2>/dev/null | \
                  grep "KERNELS==" | head -1 | sed 's/.*KERNELS=="//' | sed 's/"//')
        
        if [[ -z "$kernels" ]]; then
            echo "# ERROR: Could not extract KERNELS for $dev" >&2
            continue
        fi
        
        echo "SUBSYSTEM==\"tty\", KERNELS==\"$kernels\", \\"
        echo "  SYMLINK+=\"cisco${count}\", MODE=\"0660\", GROUP=\"dialout\""
        
    else
        # Serial-based mode (default)
        if [[ -z "$serial" ]]; then
            echo "# WARNING: No serial number - use KERNELS mode instead:" >&2
            echo "#   $(basename "$0") -k $devname" >&2
            echo "# Skipping $dev (no serial)" 
            echo
            continue
        fi
        
        echo "SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$vendor\", ATTRS{idProduct}==\"$model\", \\"
        echo "  ATTRS{serial}==\"$serial\", SYMLINK+=\"cisco${count}\", MODE=\"0660\", GROUP=\"dialout\""
    fi
    
    echo
    ((count++))
done

if [[ $count -eq 0 ]]; then
    echo "# No rules generated"
else
    echo "# Generated $count rule(s)"
    echo "# Next steps:"
    echo "#   1. Review rules above"
    echo "#   2. Append to z21_persistent-local.rules (or copy/paste)"
    echo "#   3. Run: sudo ./udev_set.sh"
fi
