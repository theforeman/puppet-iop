#!/bin/bash

URL=$1

if [[ -z "$URL" ]]; then
    echo "Usage $0 URL [output]"
    echo
    echo "Example: $0 https://security.access.redhat.com/data/meta/v1/cvemap.xml"
    exit 1
fi

BASE_FILE_NAME=$2
if [[ -z "$BASE_FILE_NAME" ]]; then
    BASE_FILE_NAME=$(basename "$URL")
fi

ETAG_STORAGE_FILE="${BASE_FILE_NAME}.etag"
LATEST_SYMLINK_NAME="${BASE_FILE_NAME}"
DOWNLOAD_FILE_PATH="${BASE_FILE_NAME}-$(date +%Y%m%d%H%M%S)"

# Initialize Etag variable
CURRENT_ETAG=""
if [[ -f "$ETAG_STORAGE_FILE" ]]; then
    CURRENT_ETAG=$(cat "$ETAG_STORAGE_FILE")
fi

SERVER_ETAG=$(curl -s -I "$URL" | grep -i '^etag:' | sed 's/Etag: //i' | tr -d '\r')
if [[ -n "$SERVER_ETAG" && "$SERVER_ETAG" == "$CURRENT_ETAG" ]]; then
    echo "Content not modified (ETag $CURRENT_ETAG)"
    exit 0
fi

echo "Downloading $URL"
HEADERS_TEMP_FILE=$(mktemp)
HTTP_STATUS=$(curl -s -D "$HEADERS_TEMP_FILE" -o "$DOWNLOAD_FILE_PATH" -w "%{http_code}" "$URL")

if [[ "$HTTP_STATUS" -eq 200 ]]; then
    echo "Download successful"

    # Extract the new Etag from the temporary headers file
    grep -i '^etag:' "$HEADERS_TEMP_FILE" | sed 's/Etag: //i' | tr -d '\r' > "$ETAG_STORAGE_FILE"

    # Create or update the symlink to point to the newly downloaded file
    if [[ -L "$LATEST_SYMLINK_NAME" ]]; then
        # Remove existing symlink and the file it points to
        OLD_FILE=$(readlink $LATEST_SYMLINK_NAME)
        rm "$OLD_FILE"
        rm "$LATEST_SYMLINK_NAME"
        echo "Removed old symlink: '$LATEST_SYMLINK_NAME'; and file '$OLD_FILE'"
    elif [[ -f "$LATEST_SYMLINK_NAME" ]]; then
        # If it's a regular file by mistake, remove it
        rm "$LATEST_SYMLINK_NAME"
        echo "Warning: '$LATEST_SYMLINK_NAME' was a regular file, removed it"
    fi
    ln -s "$DOWNLOAD_FILE_PATH" "$LATEST_SYMLINK_NAME"
    echo "Symlink '$LATEST_SYMLINK_NAME' now points to '$DOWNLOAD_FILE_PATH'"

else
    echo "Error: Download failed with HTTP status code $HTTP_STATUS."
    exit 1
fi

# Clean up temporary headers file
if [[ -f "$HEADERS_TEMP_FILE" ]]; then
    rm "$HEADERS_TEMP_FILE"
fi
