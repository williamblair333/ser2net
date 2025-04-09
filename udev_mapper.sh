#!/bin/bash

# udev_mapper.sh - A script to manage udev rules for USB devices

# Usage function
display_help() {
    echo "Usage: udev_mapper.sh -t <ttyUSB*> -u <usbX>"
    echo "  -t, --tty     Specify the ttyUSB device (e.g., ttyUSB10)"
    echo "  -u, --usb     Specify the usbX group (e.g., usb2)"
    echo "  -h, --help    Display this help message"
    echo "\nExamples:"
    echo "  udev_mapper.sh -t ttyUSB10 -u usb2"
    echo "  udev_mapper.sh --tty ttyUSB3 --usb usb1"
    exit 0
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -t|--tty)
            ttyUSB="$2"
            shift 2
            ;;
        -u|--usb)
            usbX="$2"
            shift 2
            ;;
        -h|--help)
            display_help
            ;;
        *)
            echo "Unknown option: $1"
            display_help
            ;;
    esac
done

# Validate required arguments
if [[ -z "$ttyUSB" || -z "$usbX" ]]; then
    echo "Error: Missing required arguments."
    display_help
fi

z21_file="z21_persistent-local.rules"

# Find device path
tty_entry=$(find /sys/ -name "$ttyUSB" -type d 2>/dev/null | awk 'NR==1{print $1; exit}')
if [[ -z "$tty_entry" ]]; then
    echo "Error: Device $ttyUSB not found."
    exit 1
fi

# Extract first 3 attributes
readarray -t attrs < <(sudo udevadm info --attribute-walk --path="$tty_entry" | grep 'KERNELS\|SUBSYSTEMS\|DRIVERS' | head -n3 | sed 's/^ *//')
if [[ ${#attrs[@]} -ne 3 ]]; then
    echo "Error: Could not retrieve device attributes."
    exit 1
fi

kernels=${attrs[0]}
subsystems=${attrs[1]}
drivers=${attrs[2]}

# Check if entry already exists in z21_persistent-local.rules
existing_entry=$(grep -F "$kernels,$subsystems,$drivers" "$z21_file" 2>/dev/null)
if [[ -n "$existing_entry" ]]; then
    echo "Entry already exists:"
    echo "$existing_entry"
    exit 0
fi

# Find the next available pY value in the specified usbX
max_pY=$(grep -oP "$usbX""p\d+" "$z21_file" 2>/dev/null | awk -F 'p' '{print $2}' | sort -n | tail -1)
if [[ -z "$max_pY" ]]; then
    next_pY=0  # Start at 0 if no previous entries exist
else
    next_pY=$((max_pY + 1))
fi
new_symlink="$usbX""p$next_pY"

# Append new rule
echo "$kernels,$subsystems,$drivers,SYMLINK+="\"$new_symlink\""" | sudo tee -a "$z21_file"

echo "Added new rule:"
echo "$kernels,$subsystems,$drivers,SYMLINK+="\"$new_symlink\"""

