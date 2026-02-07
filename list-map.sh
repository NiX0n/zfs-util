#!/bin/bash

# Constant variable for the filename
readonly FILENAME="input_mapping.txt"

# Confirm action function
confirm_action() {
    read -p "Process file $FILENAME? (yes/no): " response
    [[ "${response,,}" =~ ^(yes|y)$ ]] || exit 1
}

# Check file existence
if [[ ! -f "$FILENAME" ]]; then
    echo "Error: File $FILENAME does not exist."
    exit 1
fi

# Confirm before processing
confirm_action

# Process two-column input with robust handling of spaces
while IFS=$'\t' read -r -d '' key value
do
    # Additional trimming to handle potential edge cases
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    # Skip empty lines
    [[ -z "$key" || -z "$value" ]] && continue
    
    # Print or process the key-value pair
    echo "Key: '$key', Value: '$value'"
    
    # Example of more complex processing
    # case "$key" in
    #     server)
    #         ping -c 4 "$value"
    #         ;;
    #     *)
    #         echo "Processing $key with value $value"
    #         ;;
    # esac
    
done < "$FILENAME"

echo "Processing complete."

