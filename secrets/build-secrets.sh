#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path-to-root-password-file> <path-to-jcnr-license-file>"
    exit 1
fi

OUTPUT_FILE=./jcnr-secrets.yaml
ROOT_PASSWORD_FILE=$1
JCNR_LICENSE_FILE=$2

# Get the base64 encoded values
ENCODED_ROOT_PASSWORD=$(base64 -w 0 ${ROOT_PASSWORD_FILE})
ENCODED_JCNR_LICENSE=$(base64 -w 0 ${JCNR_LICENSE_FILE})

# Template string with replaced placeholders
OUTPUT_STRING=$(cat <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: jcnr
---
apiVersion: v1
kind: Secret
metadata:
  name: jcnr-secrets
  namespace: jcnr
data:
  root-password: ${ENCODED_ROOT_PASSWORD}
  crpd-license: |
    ${ENCODED_JCNR_LICENSE}
EOF
)

# Writing the template to the output file
echo "${OUTPUT_STRING}" > ${OUTPUT_FILE}
