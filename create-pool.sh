#!/bin/bash

# Constant variable for the filename
readonly FILENAME="DEVICES"

# Check if the file exists
if [[ ! -f "$FILENAME" ]]; then
    echo "Error: File $FILENAME does not exist."
    exit 1
fi

# Initialize pool_members as an empty array (recommended over string concatenation)
pool_members=()

# Read the file line by line and process each disk_id
while IFS= read -r disk_id
do
    # Trim whitespace from the disk_id
    disk_id=$(echo "$disk_id" | xargs)

    # Skip empty lines
    if [[ -z "$disk_id" ]]; then
        continue
    fi

    lnk="/dev/disk/by-id/$disk_id"

    if [[ ! -e "$lnk" ]]; then
        echo "Error: device $lnk does not exist."
        exit 1
    }    
    
    # Echo processing (for debugging/logging)
    echo "Processing: $disk_id"
    
    # Add to array instead of string concatenation
    pool_members+=("$lnk")

done < "$FILENAME"

# Check if pool_members is empty before creating pool
if [[ ${#pool_members[@]} -eq 0 ]]; then
    echo "Error: No valid devices found in $FILENAME"
    exit 1
fi

# Create zpool with array expansion
zpool create -m /mnt/shenanigans -f shenanigans raidz2 "${pool_members[@]}"

