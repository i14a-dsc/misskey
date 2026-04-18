#!/bin/bash

echo "Starting Misskey with configuration validation..."

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}OK: $1${NC}"
}

# Function to check required packages
check_required_packages() {
    MISSING_PACKAGES=()

    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        MISSING_PACKAGES+=("docker")
    fi

    # Check Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        MISSING_PACKAGES+=("docker-compose")
    fi

    # Check basic utilities
    for cmd in sed grep mkdir chmod; do
        if ! command -v $cmd >/dev/null 2>&1; then
            MISSING_PACKAGES+=("$cmd")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        error_exit "Missing required packages: ${MISSING_PACKAGES[*]}. Please install them before running this script."
    fi

    success "All required packages are installed"
}

# Check required packages
check_required_packages

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
