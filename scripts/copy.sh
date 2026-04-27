#!/bin/bash

echo "=== Misskey Configuration Copy Script ==="
echo "This script copies template files to actual configuration files."
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

# Check if we're in the correct directory
if [ ! -f "template.compose.yml" ]; then
    error_exit "template.compose.yml not found. Please run this script from the repository root directory."
fi

copy_template() {
    local template_file=$1
    local target_file=$2
    
    if [ ! -f "$template_file" ]; then
        warning "Template file $template_file not found, skipping..."
        return 1
    fi
    
    if [ -f "$target_file" ]; then
        warning "$target_file already exists."
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Skipping $target_file"
            return 0
        fi
    fi
    
    cp "$template_file" "$target_file"
    success "Created $target_file from $template_file"
    return 0
}

echo "Copying template files..."
echo ""

# Copy essential configuration files
copy_template "template.compose.yml" "compose.yml"
copy_template "template.default.yml" "default.yml"
copy_template "template.docker.env" "docker.env"

echo ""
echo "Optional configuration files:"

# Copy optional configuration files
copy_template "template.tunnel.env" "tunnel.env"
copy_template "template.anubis.env" "anubis.env"

echo ""
success "Template copy process completed!"
echo ""
echo "Next steps:"
echo "1. Edit default.yml to set your domain and other settings"
echo "2. Edit docker.env to set secure passwords"
echo "3. (Optional) Edit tunnel.env or anubis.env if needed"
echo "4. (Optional) Edit compose.yml to customize services"
echo "5. Run: docker compose up -d"
