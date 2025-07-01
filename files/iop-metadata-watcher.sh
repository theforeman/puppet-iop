#!/bin/bash

set -euo pipefail

WATCH_FILE="/var/lib/foreman/cvemap.xml"
SCRIPT_PATH="/usr/local/bin/iop-metadata-download.sh"
BASE_URL="$1"
OUTPUT_FILE="$2"

if [[ -z "$BASE_URL" || -z "$OUTPUT_FILE" ]]; then
    echo "Usage: $0 BASE_URL OUTPUT_FILE" >&2
    exit 1
fi

echo "Starting file watcher for $WATCH_FILE using polling mode"

# Function to run the copy script
run_copy() {
    echo "File change detected, running copy script"
    if "$SCRIPT_PATH" "$BASE_URL" "$OUTPUT_FILE"; then
        echo "Copy script completed successfully"
    else
        echo "Copy script failed with exit code $?" >&2
    fi
}

# Initialize tracking variables
LAST_MTIME=""
FILE_EXISTS=false

# If file already exists on startup, run copy once
if [[ -f "$WATCH_FILE" ]]; then
    echo "File exists on startup, running initial copy"
    LAST_MTIME=$(stat -c %Y "$WATCH_FILE" 2>/dev/null || echo "0")
    FILE_EXISTS=true
    run_copy
fi

# Monitor for file changes using polling
while true; do
    if [[ -f "$WATCH_FILE" ]]; then
        CURRENT_MTIME=$(stat -c %Y "$WATCH_FILE" 2>/dev/null || echo "0")
        
        # Check if file was just created
        if [[ "$FILE_EXISTS" == false ]]; then
            echo "File creation detected via polling"
            FILE_EXISTS=true
            LAST_MTIME="$CURRENT_MTIME"
            run_copy
        # Check if file was modified
        elif [[ "$CURRENT_MTIME" != "$LAST_MTIME" ]]; then
            echo "File modification detected via polling"
            LAST_MTIME="$CURRENT_MTIME"
            run_copy
        fi
    else
        # File doesn't exist, reset state
        if [[ "$FILE_EXISTS" == true ]]; then
            echo "File deletion detected"
            FILE_EXISTS=false
            LAST_MTIME=""
        fi
    fi
    
    sleep 5
done