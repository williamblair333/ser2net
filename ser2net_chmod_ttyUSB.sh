#!/bin/bash
# Check if any /dev/ttyUSB* devices exist
if ls /dev/ttyUSB* 1> /dev/null 2>&1; then
    # Change permissions to 0666
    chmod 0666 /dev/ttyUSB*
else
    echo "No /dev/ttyUSB* devices found."
fi
