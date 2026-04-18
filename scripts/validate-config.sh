#!/bin/bash

echo "=== Misskey Configuration Validation ==="

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

ERRORS=0

error_exit() {
    echo -e "${RED}ERROR: $1${NC}"
    echo -e "${RED}Please fix this issue before starting Misskey.${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    echo -e "${YELLOW}It's recommended to fix this for better security.${NC}"
}

success() {
    echo -e "${GREEN}OK: $1${NC}"
}

if [ ! -f "default.yml" ]; then
    error_exit "default.yml not found. Please copy template.default.yml to default.yml and configure it."
fi

if grep -q "https://your.host" default.yml; then
    error_exit "Default URL 'https://your.host' found in default.yml. Please set your actual domain."
else
    success "URL is configured"
fi

if grep -q "PLEASE_CHANGE_HERE_FOR_SECURITY_REASON" default.yml; then
    error_exit "Default password 'PLEASE_CHANGE_HERE_FOR_SECURITY_REASON' found in default.yml. Please set a secure password."
else
    success "Password is configured"
fi

if [ ! -f "docker.env" ]; then
    error_exit "docker.env not found. Please copy template.docker.env to docker.env and configure it."
fi

if grep -q "PLEASE_CHANGE_HERE_FOR_SECURITY_REASON" docker.env; then
    error_exit "Default PostgreSQL password found in docker.env. Please set a secure password."
else
    success "PostgreSQL password is configured"
fi

if grep -q "PLEASE_CHANGE_HERE_FOR_SECURITY_REASON" docker.env; then
    warning "Default Meilisearch key found. Consider setting a secure key for production."
else
    success "Meilisearch key is configured"
fi

if [ -f "tunnel.env" ]; then
    if grep -q "your_tunnel_token_here" tunnel.env; then
        warning "Default tunnel token found in tunnel.env. Please set your actual Cloudflare tunnel token if you want to use tunneling."
    else
        success "Tunnel token is configured"
    fi
fi

# Configuration consistency validation
echo ""
echo "=== Configuration Consistency Validation ==="

# Extract values from default.yml
if [ -f "default.yml" ]; then
    DEFAULT_URL=$(grep "^url:" default.yml | sed 's/url: //' | sed 's/^[[:space:]]*//')
    DEFAULT_PORT=$(grep "^port:" default.yml | sed 's/port: //' | sed 's/^[[:space:]]*//')
    DEFAULT_HOST=$(grep "^host:" default.yml | sed 's/host: //' | sed 's/^[[:space:]]*//')
else
    error_exit "default.yml not found for consistency validation"
fi

# Extract values from docker.env
if [ -f "docker.env" ]; then
    DOCKER_URL=$(grep "^MISSKEY_URL=" docker.env | sed 's/MISSKEY_URL=//' | sed 's/^[[:space:]]*//')
    DOCKER_PORT=$(grep "^MISSKEY_PORT=" docker.env | sed 's/MISSKEY_PORT=//' | sed 's/^[[:space:]]*//')
    DOCKER_HOST=$(grep "^MISSKEY_HOST=" docker.env | sed 's/MISSKEY_HOST=//' | sed 's/^[[:space:]]*//')
else
    error_exit "docker.env not found for consistency validation"
fi

# URL consistency check
if [ "$DEFAULT_URL" = "$DOCKER_URL" ]; then
    success "URL is consistent between default.yml and docker.env: $DEFAULT_URL"
else
    error_exit "URL mismatch: default.yml has '$DEFAULT_URL' but docker.env has '$DOCKER_URL'"
fi

# Port consistency check
if [ "$DEFAULT_PORT" = "$DOCKER_PORT" ]; then
    success "Port is consistent between default.yml and docker.env: $DEFAULT_PORT"
else
    error_exit "Port mismatch: default.yml has '$DEFAULT_PORT' but docker.env has '$DOCKER_PORT'"
fi

# Host consistency check
if [ "$DEFAULT_HOST" = "$DOCKER_HOST" ]; then
    success "Host is consistent between default.yml and docker.env: $DEFAULT_HOST"
else
    error_exit "Host mismatch: default.yml has '$DEFAULT_HOST' but docker.env has '$DOCKER_HOST'"
fi

if [ ! -d "files" ]; then
    echo "Creating files directory..."
    mkdir -p files
fi

if [ ! -w "files" ]; then
    error_exit "files directory is not writable. Please check permissions."
else
    success "files directory is writable"
fi

if [ ! -d "db" ]; then
    echo "Creating db directory..."
    mkdir -p db
    success "db directory created"
else
    success "db directory exists"
fi

if [ ! -d "meili_data" ]; then
    echo "Creating meili_data directory..."
    mkdir -p meili_data
    success "meili_data directory created"
else
    success "meili_data directory exists"
fi

echo ""
echo -e "${GREEN}=== Configuration validation completed successfully! ===${NC}"
echo -e "${GREEN}You can now start Misskey with: docker compose up -d${NC}"
