#!/bin/bash

LOCK_FILE="/tmp/update_ssh_config.lock"

while [ -e $LOCK_FILE ]; do
    sleep 1
done

touch $LOCK_FILE

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
ALIAS=$1
HOSTNAME=$2
SSH_KEY_PATH=$3

# Check if the .ssh directory exists
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p $SSH_DIR
    chmod 700 $SSH_DIR
fi

# Create the .ssh/config file if it doesn't exist
touch $SSH_CONFIG
chmod 600 $SSH_CONFIG

# Prepare the updated entry with sub-parameters
ENTRY="Host $ALIAS
  HostName $HOSTNAME
  HostKeyAlgorithms=+ssh-rsa
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
  Port 22
  User ec2-user
  ServerAliveInterval 300
  ServerAliveCountMax 2
  IdentityFile $SSH_KEY_PATH"

# If the entry exists, delete the full entry and its sub-parameters
if grep -q "Host $ALIAS" $SSH_CONFIG; then
    awk -v alias="$ALIAS" '
        $1 == "Host" && $2 == alias { skip = 1; next }
        $1 == "Host" && $2 != alias { skip = 0 }
        skip { next }
        1' $SSH_CONFIG > ${SSH_CONFIG}.tmp && mv ${SSH_CONFIG}.tmp $SSH_CONFIG
fi

# Append the new (or updated) entry with an additional newline for separation
echo -e "\n$ENTRY\n" >> $SSH_CONFIG

rm -f $LOCK_FILE

