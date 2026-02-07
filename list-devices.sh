#!/bin/bash

# Constant variable for the filename
readonly FILENAME="DEVICES"

# Check if the file exists
if [[ ! -f "$FILENAME" ]]; then
    echo "Error: File $FILENAME does not exist."
    exit 1
fi

# Read the file line by line and process each device
while IFS= read -r device
do
    # Trim whitespace from the device
    device=$(echo "$device" | xargs)
    
    # Skip empty lines
    if [[ -z "$device" ]]; then
        continue
    fi
    
    # Example of executing an arbitrary command with the device
    # Here, we're just echoing the device, but you can replace this with any command
    echo "Processing: $device"
    
    
done < "$FILENAME"

