#!/bin/sh

# Define the XML file and a temporary file
XML_FILE="$1"
PREFIX="$2"
TEMP_FILE="$(mktemp)"

# Ensure XML file exists
if [ ! -f "$XML_FILE" ]; then
    echo "XML file not found."
    exit 1
fi

# Function to extract a node value from the XML
extract_node_value() {
    node_name="$1"
    sed -n "s|<${node_name}>\(.*\)</${node_name}>|\1|p" "$XML_FILE"
}

# Function to replace a node value in the XML
replace_node_value_sed() {
    node_name="$1"
    new_value="$2"
    sed "s|<${node_name}>.*</${node_name}>|<${node_name}>${new_value}</${node_name}>|g"
}

# Copy original XML file to temporary file
cp "$XML_FILE" "$TEMP_FILE"

# Read each node in the Config element and apply changes
sed -n 's|^[ \t]*<\([^>]*\)>.*</\1>|\1|p' "$XML_FILE" | sort -u | while IFS= read -r node; do
    # Create environment variable name in uppercase
    env_name="${PREFIX}__${node}"
    env_name=$(printf '%s' "$env_name" | tr '[:lower:]' '[:upper:]')

    # Check if the corresponding environment variable exists
    env_value=$(printenv "$env_name")
    if [ -z "$env_value" ]; then
        continue
    fi

    # Get the current value of the node from the XML file
    current_value=$(extract_node_value "$node")

    if [ "$current_value" != "$env_value" ]; then
        echo "Changing '${node}' from '${current_value}' to '${env_value}'."

        # Apply the replacement to the temporary file content
        TEMP_CONTENT=$(replace_node_value_sed "$node" "$env_value" <"${TEMP_FILE}")
        echo "$TEMP_CONTENT" >"$TEMP_FILE"
    fi
done

# Check if changes were made by comparing the original file with the temporary file
if ! cmp -s "$XML_FILE" "$TEMP_FILE"; then
    # If changes were made, replace the original file with the temporary file
    mv "$TEMP_FILE" "$XML_FILE"
else
    # If no changes were made, remove the temporary file
    rm "$TEMP_FILE"
fi
