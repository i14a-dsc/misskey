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

detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/gentoo-release ]; then
        echo "gentoo"
    else
        echo "unknown"
    fi
}

check_required_packages() {
    MISSING_PACKAGES=()

    if ! command -v docker >/dev/null 2>&1; then
        MISSING_PACKAGES+=("docker")
    fi

    if ! docker compose version >/dev/null 2>&1; then
        MISSING_PACKAGES+=("docker-compose")
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        MISSING_PACKAGES+=("openssl")
    fi

    for cmd in sed grep mkdir chmod; do
        if ! command -v $cmd >/dev/null 2>&1; then
            MISSING_PACKAGES+=("$cmd")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        echo "${MISSING_PACKAGES[@]}"
        return 1
    fi

    success "All required packages are installed"
    return 0
}

install_missing_packages() {
    local missing=("$@")
    local distro=$(detect_distribution)

    case "$distro" in
        arch|archlinux)
            info "Detected Arch Linux. Installing missing packages: ${missing[*]}"
            sudo pacman -S --noconfirm "${missing[@]}"
            sudo systemctl enable --now docker 2>/dev/null
            ;;
        fedora|rhel|centos)
            info "Detected RPM-based distribution. Installing missing packages: ${missing[*]}"
            sudo dnf install -y "${missing[@]}"
            sudo systemctl enable --now docker 2>/dev/null
            ;;
        ubuntu|debian|zorin)
            info "Detected Debian-based distribution. Installing missing packages: ${missing[*]}"
            local debian_packages=()
            for pkg in "${missing[@]}"; do
                case "$pkg" in
                    docker) debian_packages+=("docker.io") ;;
                    docker-compose) debian_packages+=("docker-compose") ;;
                    *) debian_packages+=("$pkg") ;;
                esac
            done
            sudo apt update
            sudo apt install -y "${debian_packages[@]}"
            sudo systemctl enable --now docker 2>/dev/null
            ;;
        sles|opensuse|suse)
            info "Detected SUSE-based distribution. Installing missing packages: ${missing[*]}"
            local suse_packages=()
            for pkg in "${missing[@]}"; do
                case "$pkg" in
                    docker) suse_packages+=("docker") ;;
                    docker-compose) suse_packages+=("docker-compose") ;;
                    *) suse_packages+=("$pkg") ;;
                esac
            done
            sudo zypper install -y "${suse_packages[@]}"
            sudo systemctl enable --now docker 2>/dev/null
            ;;
        gentoo)
            info "Detected Gentoo. Installing missing packages: ${missing[*]}"
            local emerge_packages=()
            for pkg in "${missing[@]}"; do
                case "$pkg" in
                    docker) emerge_packages+=("app-containers/docker") ;;
                    docker-compose) emerge_packages+=("app-containers/docker-compose") ;;
                    openssl) emerge_packages+=("dev-libs/openssl") ;;
                    sed) emerge_packages+=("sys-apps/sed") ;;
                    grep) emerge_packages+=("sys-apps/grep") ;;
                    mkdir) emerge_packages+=("sys-apps/coreutils") ;;
                    chmod) emerge_packages+=("sys-apps/coreutils") ;;
                    *) emerge_packages+=("$pkg") ;;
                esac
            done
            sudo emerge -n "${emerge_packages[@]}"
            sudo rc-update add docker default 2>/dev/null
            sudo rc-service docker start 2>/dev/null
            ;;
        *)
            error_exit "Unknown distribution. Cannot auto-install packages. Please install manually: ${missing[*]}"
            ;;
    esac

    if [ $? -eq 0 ]; then
        success "Missing packages installed successfully"
    else
        error_exit "Failed to install packages. Please install manually: ${missing[*]}"
    fi
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

echo "Checking required packages..."
MISSING=$(check_required_packages)
CHECK_STATUS=$?

if [ $CHECK_STATUS -ne 0 ]; then
    MISSING_ARRAY=($MISSING)
    warning "Missing required packages: ${MISSING_ARRAY[*]}"
    echo ""
    local distro=$(detect_distribution)
    if [ "$distro" != "unknown" ]; then
        info "Detected distribution: $distro"
        read -p "Do you want to automatically install missing packages? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_missing_packages "${MISSING_ARRAY[@]}"
            MISSING=$(check_required_packages)
            CHECK_STATUS=$?
            if [ $CHECK_STATUS -ne 0 ]; then
                error_exit "Some packages are still missing after installation. Please install them manually."
            fi
        else
            error_exit "Please install the missing packages manually before running this script."
        fi
    else
        error_exit "Unknown distribution. Cannot auto-install packages. Please install manually: ${MISSING_ARRAY[*]}"
    fi
fi

generate_api_key() {
    openssl rand -hex 16
}

if [ ! -f "template.default.yml" ]; then
    error_exit "template.default.yml not found. Are you in the correct directory?"
fi

if [ ! -f "template.docker.env" ]; then
    error_exit "template.docker.env not found. Are you in the correct directory?"
fi

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

ANUBIS_ENABLED=false
ANUBIS_ROBOTS_TXT=false
read -p "Do you want to enable Anubis bot protection? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ANUBIS_ENABLED=true
    info "Anubis bot protection will be enabled"
    
    read -p "Do you want to serve robots.txt with disallow all? (blocks search engine crawlers) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ANUBIS_ROBOTS_TXT=true
        info "robots.txt with disallow all will be enabled"
    else
        info "robots.txt will not be served"
    fi
else
    info "Anubis bot protection will not be enabled"
fi

read -p "Enter your domain (e.g., misskey.example.com) or press Enter for localhost: " DOMAIN

if [ -z "$DOMAIN" ]; then
    MISSKEY_URL="http://localhost:3000"
    info "Using localhost configuration"
else
    MISSKEY_URL="https://$DOMAIN"
    info "Using domain: $DOMAIN"
fi

echo "Step 3: Creating configuration files..."

cp template.default.yml default.yml
sed -i "s|https://your.host|$MISSKEY_URL|g" default.yml
sed -i "s|PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|$MISSKEY_PASSWORD|g" default.yml
sed -i "s|pass: $MISSKEY_PASSWORD|pass: $POSTGRES_PASSWORD|g" default.yml
sed -i "s|apiKey: $MISSKEY_PASSWORD|apiKey: $MEILI_KEY|g" default.yml

cp template.docker.env docker.env
sed -i "s|PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|$POSTGRES_PASSWORD|g" docker.env
sed -i "s|https://your.host|$MISSKEY_URL|g" docker.env

sed -i "s|MEILI_MASTER_KEY=PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|MEILI_MASTER_KEY=$MEILI_KEY|g" docker.env

if grep -q "MEILI_MASTER_KEY: PLEASE_CHANGE_HERE_FOR_SECURITY_REASON" compose.yml; then
    sed -i "s|MEILI_MASTER_KEY: PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|MEILI_MASTER_KEY: $MEILI_KEY|g" compose.yml
fi

success "Configuration files created and updated"

echo "Step 4: Creating necessary directories..."
mkdir -p files db meili_data
success "Directories created"

if [ "$ANUBIS_ENABLED" = true ]; then
    echo "Step 4.5: Setting up Anubis bot protection..."
    if [ -f "template.anubis.env" ]; then
        cp template.anubis.env anubis.env
        
        if [ "$ANUBIS_ROBOTS_TXT" = true ]; then
            sed -i 's/^# SERVE_ROBOTS_TXT=true/SERVE_ROBOTS_TXT=true/' anubis.env
            success "Anubis configuration file created (with robots.txt)"
        else
            success "Anubis configuration file created"
        fi
        
        if [ -f "compose.yml" ]; then
            sed -i 's/^#  anubis:/  anubis:/' compose.yml
            sed -i 's/^#    image: ghcr.io\/techarohq\/anubis:/    image: ghcr.io\/techarohq\/anubis:/' compose.yml
            sed -i 's/^#    restart: always/    restart: always/' compose.yml
            sed -i 's/^#    env_file:/    env_file:/' compose.yml
            sed -i 's/^#      - .\/anubis.env/      - .\/anubis.env/' compose.yml
            sed -i 's/^#    ports:/    ports:/' compose.yml
            sed -i 's/^#      - 3000:8080/      - 3000:8080/' compose.yml
            sed -i 's/^#    environment:/    environment:/' compose.yml
            sed -i 's/^#      - TARGET=web:8080/      - TARGET=web:8080/' compose.yml
            sed -i 's/^#    networks:/    networks:/' compose.yml
            sed -i 's/^#      - internal_network$/      - internal_network/' compose.yml
            
            sed -i 's/\(    ports:\)/    # ports:/' compose.yml
            sed -i 's/\(      - 3000:8080\)/      # - 3000:8080/' compose.yml
            
            success "Anubis service enabled in compose.yml"
            info "Note: Port 3000 is now handled by Anubis, not the web service"
        else
            warning "compose.yml not found, cannot enable Anubis automatically"
        fi
    else
        warning "template.anubis.env not found, skipping Anubis setup"
    fi
fi

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
        if [ "$ANUBIS_ENABLED" = true ]; then
            echo "Access Misskey at: $MISSKEY_URL (protected by Anubis)"
            echo ""
            echo "Anubis bot protection is enabled and running on port 3000"
        else
            echo "Access Misskey at: $MISSKEY_URL"
        fi
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
