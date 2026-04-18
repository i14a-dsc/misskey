#!/bin/bash

echo "=== Misskey Clean Script ==="
echo "This script will stop all services and remove all data and configuration files."
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

# Safety confirmation
echo "This will permanently delete:"
echo "- All Docker containers and networks"
echo "- Database data (db/)"
echo "- User uploaded files (files/)"
echo "- Search index data (meili_data/)"
echo "- Configuration files (default.yml, docker.env, tunnel.env)"
echo ""

read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Clean cancelled."
    exit 0
fi

echo "Step 1: Stopping and removing Docker services..."
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose down -v --remove-orphans
    if [ $? -eq 0 ]; then
        success "Docker services stopped and removed"
    else
        warning "Docker compose down failed, continuing with cleanup..."
    fi
else
    warning "Docker not found, skipping container cleanup"
fi

echo "Step 2: Removing data directories..."
directories=("db" "files" "meili_data")
for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo "Removing $dir/ directory..."
        rm -rf "$dir" 2>/dev/null
        if [ $? -eq 0 ]; then
            success "Removed $dir/ directory"
        else
            echo "Trying with elevated permissions for $dir/..."
            if command -v run0 >/dev/null 2>&1; then
                run0 rm -rf "$dir" 2>/dev/null
                if [ $? -eq 0 ]; then
                    success "Removed $dir/ directory with elevated permissions"
                else
                    warning "Failed to remove $dir/ directory even with elevated permissions"
                fi
            elif command -v sudo >/dev/null 2>&1; then
                sudo rm -rf "$dir" 2>/dev/null
                if [ $? -eq 0 ]; then
                    success "Removed $dir/ directory with sudo"
                else
                    warning "Failed to remove $dir/ directory even with sudo"
                fi
            else
                warning "Failed to remove $dir/ directory (no elevated access available)"
            fi
        fi
    else
        info "$dir/ directory does not exist"
    fi
done

echo "Step 3: Removing configuration files..."
config_files=("default.yml" "docker.env" "tunnel.env")
for file in "${config_files[@]}"; do
    if [ -f "$file" ]; then
        echo "Removing $file..."
        rm -f "$file"
        if [ $? -eq 0 ]; then
            success "Removed $file"
        else
            warning "Failed to remove $file"
        fi
    else
        info "$file does not exist"
    fi
done

echo "Step 4: Removing Docker volumes (if any)..."
if command -v docker >/dev/null 2>&1; then
    # Remove any orphaned volumes
    docker volume prune -f >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "Cleaned up Docker volumes"
    else
        info "No Docker volumes to clean"
    fi
fi

echo "Step 5: Removing Docker networks (if any)..."
if command -v docker >/dev/null 2>&1; then
    # Remove any orphaned networks
    docker network prune -f >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "Cleaned up Docker networks"
    else
        info "No Docker networks to clean"
    fi
fi

echo ""
echo -e "${GREEN}=== Clean Complete! ===${NC}"
echo "All Misskey data and configurations have been removed."
echo "You can now run './scripts/auto-setup.sh' to start fresh."
echo ""

# Show remaining files for verification
echo "Remaining files in current directory:"
ls -la | grep -v "^total" | awk '{print $9}' | grep -E "^\." || echo "No hidden files"
ls -la | grep -v "^total" | awk '{print $9}' | grep -v "^\.$" | grep -v "^\.\.$" | grep -v "^\." || echo "No regular files"
