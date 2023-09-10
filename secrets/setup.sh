#!/bin/bash

# Function to silently get contents from file or write user input to an output file
get_input_or_prompt_to_file() {
    local prompt=$1
    local file=$2
    local outfile=$3
    local default_message=$4

    if [[ -f $file ]]; then
        echo "Reading $default_message from $file"
        cp "$file" "$outfile"
    else
        read -sp "$prompt: " content
        echo "$content" > "$outfile"
    fi
}

# Function to get multi-line input until a delimiter (END) is detected, and write it to an output file
get_multiline_input_or_prompt_to_file() {
    local prompt=$1
    local file=$2
    local outfile=$3
    local default_message=$4

    if [[ -f $file ]]; then
        echo "Reading $default_message from $file"
        cp "$file" "$outfile"
    else
        echo "$prompt (Type 'END' on a new line to finish):"
        local multi_line=""
        while IFS= read -r line; do
            [[ "$line" == "END" ]] && break
            multi_line="${multi_line}${line}"$'\n'
        done
        echo "$multi_line" > "$outfile"
    fi
}

# Store root password and license key in temporary files
get_input_or_prompt_to_file "Enter root password" "jcnr-root-password.txt" "tmp-root-password.txt" "root password"
get_multiline_input_or_prompt_to_file "Enter license key" "jcnr-license.txt" "tmp-license.txt" "license key"

# Build jcnr-secrets.yaml file
echo "Creating jcnr-secrets.yaml file"
./build-secrets.sh tmp-root-password.txt tmp-license.txt

# Cleanup temporary files
rm tmp-root-password.txt tmp-license.txt

# Apply JCNR secrets and namespace
echo "Applying JCNR secrets and namespace"
kubectl apply -f jcnr-secrets.yaml

# Prompt user for key-value pair for the label or use default
read -p "Enter label in format key=value (default is key1=jcnr): " LABEL
[[ -z "$LABEL" ]] && LABEL="key1=jcnr"

# Split the key and value
KEY="${LABEL%=*}"
VALUE="${LABEL#*=}"

# Add label to eks worker nodes
echo "Adding label to eks worker nodes"
kubectl label nodes $(kubectl get nodes -o json | jq -r .items[0].metadata.name) "$KEY=$VALUE" --overwrite
