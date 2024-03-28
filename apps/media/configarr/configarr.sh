#!/bin/sh

# Initialize variables for -c and -p options
XML_FILE="" # -c option
PREFIX=""   # -p option

# Loop through all the positional parameters
while [ $# -gt 0 ]; do
    key="$1"
    case $key in
    -c | --config)
        XML_FILE="$2"
        shift # past argument
        shift # past value
        ;;
    -p | --prefix)
        PREFIX="$2"
        shift # past argument
        shift # past value
        ;;
    -h | --help)
        printf "%s\n" \
            "Usage: $(basename "$0") [options]" \
            "Options:" \
            "  -c, --config FILE     XML file to be configured" \
            "  -p, --prefix PREFIX   Prefix for environment variables" \
            "  -h, --help            Display this help and exit"
        exit 0
        ;;
    *) # unknown option
        printf "%s\n" \
            "$(basename "$0"): invalid option -- '$1'" \
            "Try '$(basename "$0") --help' for more information."
        exit 1
        ;;
    esac
done

# Ensure XML file provided
if [ -z "$XML_FILE" ]; then
    echo "XML file not provided."
    exit 1
fi

# Ensure XML file exists
if [ ! -f "$XML_FILE" ]; then
    echo "XML file not found."
    exit 1
fi

# Ensure prefix provided
if [ -z "$PREFIX" ]; then
    echo "Prefix not provided."
    exit 1
fi

# Make a temporary copy of the original XML file for comparison
TEMP_FILE_NAME=$(basename "$XML_FILE")
TEMP_FILE="$(mktemp -t "${TEMP_FILE_NAME}".XXXXXX)" # Create a temporary file with a template for naming
cp "$XML_FILE" "$TEMP_FILE"

ORIGINAL_PERMISSIONS=$(stat -c %a "$XML_FILE") # Preserve original file permissions

# Use xmlstarlet to read nodes, similar to before
xmlstarlet sel -T -t -m "//*" -v "name()" -n "$XML_FILE" | while read -r node; do
    env_name="${PREFIX}__${node}"
    env_name=$(printf '%s' "$env_name" | tr '[:lower:]' '[:upper:]')
    env_value=$(printenv "$env_name")

    if [ -n "$env_value" ]; then
        # Modify the TEMP_FILE instead of the original XML file
        xmlstarlet ed -L -u "//$node" -v "$env_value" "$TEMP_FILE"
        echo "Modified '$node' to '$env_value'"
    fi
done

# Check if changes were made by comparing the original file with the temporary file
if ! cmp -s "$TEMP_FILE" "$XML_FILE"; then
    chmod "$ORIGINAL_PERMISSIONS" "$TEMP_FILE" # Apply original file permissions to temporary file
    mv "$TEMP_FILE" "$XML_FILE"                # Move the modified temporary file to the original file location
    echo "Changes were made to the configuration."
else
    echo "No changes were made to the configuration."
fi
