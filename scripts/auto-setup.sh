#!/bin/bash

echo "=== Misskey Auto Setup Script ==="
echo "This script will automatically configure and start Misskey after git clone."
echo ""

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate random string for API keys
generate_api_key() {
    openssl rand -hex 16
}

# Check if required files exist
if [ ! -f "template.default.yml" ]; then
    error_exit "template.default.yml not found. Are you in the correct directory?"
fi

if [ ! -f "template.docker.env" ]; then
    error_exit "template.docker.env not found. Are you in the correct directory?"
fi

# Check if configuration already exists
if [ -f "default.yml" ] || [ -f "docker.env" ]; then
    warning "Configuration files already exist."
    read -p "Do you want to overwrite existing configurations? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

echo "Step 1: Generating secure passwords and keys..."
MISSKEY_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
MEILI_KEY=$(generate_api_key)

success "Generated secure passwords and API keys"

echo "Step 2: Detecting network configuration..."

# Auto-detect URL configuration
read -p "Enter your domain (e.g., misskey.example.com) or press Enter for localhost: " DOMAIN

if [ -z "$DOMAIN" ]; then
    MISSKEY_URL="http://localhost:3000"
    info "Using localhost configuration"
else
    MISSKEY_URL="https://$DOMAIN"
    info "Using domain: $DOMAIN"
fi

echo "Step 3: Creating configuration files..."

# Create default.yml
cp template.default.yml default.yml
sed -i "s|https://your.host|$MISSKEY_URL|g" default.yml
sed -i "s|PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|$MISSKEY_PASSWORD|g" default.yml
# Fix database password to match PostgreSQL password
sed -i "s|pass: $MISSKEY_PASSWORD|pass: $POSTGRES_PASSWORD|g" default.yml
# Fix Meilisearch API key
sed -i "s|apiKey: $MISSKEY_PASSWORD|apiKey: $MEILI_KEY|g" default.yml

# Create docker.env
cp template.docker.env docker.env
sed -i "s|PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|$POSTGRES_PASSWORD|g" docker.env
sed -i "s|https://your.host|$MISSKEY_URL|g" docker.env

# Update Meilisearch key in docker.env
sed -i "s|MEILI_MASTER_KEY=PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|MEILI_MASTER_KEY=$MEILI_KEY|g" docker.env

# Update Meilisearch key in compose.yml (if it contains the placeholder)
if grep -q "MEILI_MASTER_KEY: PLEASE_CHANGE_HERE_FOR_SECURITY_REASON" compose.yml; then
    sed -i "s|MEILI_MASTER_KEY: PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|MEILI_MASTER_KEY: $MEILI_KEY|g" compose.yml
fi

success "Configuration files created and updated"

echo "Step 4: Creating necessary directories..."
mkdir -p files db meili_data
success "Directories created"

echo "Step 5: Setting up file permissions..."
chmod 777 files 2>/dev/null || run0 chmod 777 files 2>/dev/null || echo "Warning: Could not set files directory permissions"
success "File permissions configured"

echo "Step 6: Making scripts executable..."
chmod +x scripts/*.sh
success "Scripts made executable"

echo "Step 7: Validating configuration..."
if [ -f "scripts/validate-config.sh" ]; then
    ./scripts/validate-config.sh
    if [ $? -ne 0 ]; then
        error_exit "Configuration validation failed"
    fi
else
    warning "validate-config.sh not found, skipping validation"
fi

echo "Step 8: Starting Misskey services..."
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose up -d
    if [ $? -eq 0 ]; then
        success "Misskey services started successfully!"
        echo ""
        echo "=== Setup Complete! ==="
        echo "Misskey is starting up. This may take a few minutes."
        echo "You can check the status with: docker compose logs -f"
        echo "Access Misskey at: $MISSKEY_URL"
        echo ""
        echo "Generated credentials (save these securely):"
        echo "Misskey Setup Password: $MISSKEY_PASSWORD"
        echo "PostgreSQL Password: $POSTGRES_PASSWORD"
        echo "Meilisearch API Key: $MEILI_KEY"
        echo ""
        echo "Important: Save these passwords in a secure location!"
    else
        error_exit "Failed to start Docker services"
    fi
else
    error_exit "Docker or Docker Compose not found. Please install Docker first."
fi

echo ""
echo -e "${GREEN}=== Auto Setup Complete! ===${NC}"
