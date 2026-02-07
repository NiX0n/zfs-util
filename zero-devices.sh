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

	# Zero out header (first 1024) bytes for each device
	# This count is arbitrarily chosen, but it works
	# It's faster than wiping each entire disk
	dd count=1024 if=/dev/zero of=/dev/disk/by-id/"$device"
    
    
done < "$FILENAME"

