#!/bin/bash

set -euo pipefail

URL="$1"
OUTPUT_FILE="$2"

if [[ -z "$URL" || -z "$OUTPUT_FILE" ]]; then
    echo "Usage: $0 URL OUTPUT_FILE" >&2
    echo "Example: $0 https://security.access.redhat.com/data/meta/v1/cvemap.xml /var/www/html/pub/cvemap.xml" >&2
    exit 1
fi

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
MANUAL_FILE="/var/lib/foreman/cvemap.xml"
CHECKSUM_FILE="${OUTPUT_FILE}.checksum"
ETAG_FILE="${OUTPUT_FILE}.etag"

mkdir -p "$OUTPUT_DIR"

if [[ -f "$MANUAL_FILE" ]]; then
    echo "Offline mode: Using manual file from $MANUAL_FILE"
    
    CURRENT_CHECKSUM=$(sha256sum "$MANUAL_FILE" | cut -d' ' -f1)
    STORED_CHECKSUM=""
    
    if [[ -f "$CHECKSUM_FILE" ]]; then
        STORED_CHECKSUM=$(cat "$CHECKSUM_FILE")
    fi
    
    if [[ "$CURRENT_CHECKSUM" != "$STORED_CHECKSUM" ]]; then
        echo "Copying updated manual file"
        
        # Retry logic for file copy operations
        MAX_RETRIES=3
        RETRY_COUNT=0
        
        while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
            if cp "$MANUAL_FILE" "$OUTPUT_FILE" && echo "$CURRENT_CHECKSUM" > "$CHECKSUM_FILE"; then
                echo "Manual file copied successfully"
                break
            else
                RETRY_COUNT=$((RETRY_COUNT + 1))
                echo "Copy attempt $RETRY_COUNT failed" >&2
                if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
                    echo "Retrying in 5 seconds..." >&2
                    sleep 5
                else
                    echo "Failed to copy manual file after $MAX_RETRIES attempts" >&2
                    exit 1
                fi
            fi
        done
    else
        echo "Manual file unchanged, skipping"
    fi
else
    echo "Online mode: Checking for updates from $URL"
    
    TEMP_FILE=$(mktemp -t "iop-metadata-download.XXXXXX")
    TEMP_HEADERS=$(mktemp)
    
    cleanup() {
        rm -f "$TEMP_FILE" "$TEMP_HEADERS"
    }
    trap cleanup EXIT
    
    CURRENT_ETAG=""
    if [[ -f "$ETAG_FILE" ]]; then
        CURRENT_ETAG=$(cat "$ETAG_FILE")
    fi
    
    HTTP_STATUS=$(curl -s \
        --fail \
        --location \
        --dump-header "$TEMP_HEADERS" \
        --output "$TEMP_FILE" \
        --write-out "%{http_code}" \
        ${CURRENT_ETAG:+--header "If-None-Match: $CURRENT_ETAG"} \
        "$URL")
    
    case "$HTTP_STATUS" in
        200)
            echo "Downloaded new version"
            NEW_ETAG=$(grep -i '^etag:' "$TEMP_HEADERS" | sed 's/^[Ee][Tt][Aa][Gg]: *//; s/\r$//' || echo "")
            
            if [[ -f "$OUTPUT_FILE" ]]; then
                echo "Replacing existing file atomically"
            else
                echo "Creating new file"
            fi
            
            mv "$TEMP_FILE" "$OUTPUT_FILE"
            
            if [[ -n "$NEW_ETAG" ]]; then
                echo "$NEW_ETAG" > "$ETAG_FILE"
                echo "Stored ETag: $NEW_ETAG"
            fi
            ;;
        304)
            echo "File not modified (ETag: $CURRENT_ETAG)"
            rm -f "$TEMP_FILE"
            ;;
        *)
            echo "Error: HTTP $HTTP_STATUS" >&2
            exit 1
            ;;
    esac
fi

echo "Update check completed successfully"