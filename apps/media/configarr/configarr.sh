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

# Read and modify the XML based on environment variables
xmlstarlet sel -T -t -m "//*" -v "name()" -n "$XML_FILE" | while read -r node; do
    env_name="${PREFIX}__${node}"
    env_name=$(printf '%s' "$env_name" | tr '[:lower:]' '[:upper:]')
    env_value=$(printenv "$env_name")

    if [ -n "$env_value" ]; then
        # Use xmlstarlet to modify the node value
        xmlstarlet ed -L -u "//$node" -v "$env_value" "$XML_FILE"
        echo "Modified '$node' to '$env_value'"
    fi
done

echo "XML modifications completed."
