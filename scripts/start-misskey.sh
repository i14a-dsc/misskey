#!/bin/bash

echo "Starting Misskey with configuration validation..."

echo "Step 1: Setting up file permissions..."
if [ -d "files" ]; then
    chmod 777 files 2>/dev/null || run0 chmod 777 files 2>/dev/null || echo "Warning: Could not set files directory permissions"
fi

echo "Step 2: Validating configuration..."
docker compose --profile validate up validate

if [ $? -eq 0 ]; then
    echo "Step 3: Configuration validation passed! Starting Misskey services..."
    docker compose up -d
    echo "Step 4: Misskey is starting up..."
    echo "You can check the status with: docker compose logs -f"
    
    # Extract URL from configuration
    if [ -f "default.yml" ]; then
        MISSKEY_URL=$(grep "^url:" default.yml | sed 's/url: //' | sed 's/^[[:space:]]*//')
        if [ -n "$MISSKEY_URL" ] && [ "$MISSKEY_URL" != "https://your.host" ]; then
            echo "Access Misskey at: $MISSKEY_URL"
        else
            echo "Access Misskey at: http://localhost:3000 (default)"
        fi
    else
        echo "Access Misskey at: http://localhost:3000 (default)"
    fi
else
    echo "Configuration validation failed. Please fix the issues above and try again."
    exit 1
fi
