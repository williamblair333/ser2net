#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_FILE="${SCRIPT_DIR}/z21_persistent-local.rules"

if [[ ! -f "$RULES_FILE" ]]; then
    echo "Error: $RULES_FILE not found"
    exit 1
fi

sudo cp "$RULES_FILE" /etc/udev/rules.d/z21_persistent-local.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --action=add --subsystem-match=tty

echo "Checking symlinks:"
ls -la /dev/cisco* 2>/dev/null || echo "No /dev/cisco* symlinks — check rules file"
