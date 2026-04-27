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
	local missing=()
	if ! command -v docker >/dev/null 2>&1; then missing+=("docker"); fi
	if ! docker compose version >/dev/null 2>&1; then missing+=("docker-compose"); fi
	if ! command -v openssl >/dev/null 2>&1; then missing+=("openssl"); fi

	for cmd in sed grep mkdir chmod; do
		if ! command -v "$cmd" >/dev/null 2>&1; then missing+=("$cmd"); fi
	done

	if [ ${#missing[@]} -ne 0 ]; then
		echo "${missing[@]}"
		return 1
	fi
	success "Verified all prerequisite packages are present."
	return 0
}

install_missing_packages() {
	local missing=("$@")
	local distro
	distro=$(detect_distribution)

	case "$distro" in
	arch | archlinux)
		info "Arch Linux detected. Installing: ${missing[*]}"
		sudo pacman -S --noconfirm "${missing[@]}"
		sudo systemctl enable --now docker 2>/dev/null
		;;
	fedora | rhel | centos)
		info "RPM-based distro detected. Installing: ${missing[*]}"
		sudo dnf install -y "${missing[@]}"
		sudo systemctl enable --now docker 2>/dev/null
		;;
	ubuntu | debian | zorin)
		info "Debian-based distro detected. Installing: ${missing[*]}"
		local debian_packages=()
		for pkg in "${missing[@]}"; do
			case "$pkg" in
			docker) debian_packages+=("docker.io") ;;
			docker-compose) debian_packages+=("docker-compose") ;;
			*) debian_packages+=("$pkg") ;;
			esac
		done
		sudo apt update && sudo apt install -y "${debian_packages[@]}"
		sudo systemctl enable --now docker 2>/dev/null
		;;
	*)
		error_exit "Automatic installation is not supported for $distro. Please install manually: ${missing[*]}"
		;;
	esac
}

generate_password() {
	openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

generate_api_key() {
	openssl rand -hex 16
}

info "Starting dependency check..."
MISSING_STR=$(check_required_packages)
CHECK_STATUS=$?

if [ $CHECK_STATUS -ne 0 ]; then
	read -ra MISSING_ARRAY <<<"$MISSING_STR"
	warning "Missing packages: ${MISSING_ARRAY[*]}"
	DISTRO=$(detect_distribution)
	if [ "$DISTRO" != "unknown" ]; then
		read -rp "Attempt automatic installation on $DISTRO? (y/N): " -n 1
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			install_missing_packages "${MISSING_ARRAY[@]}"
		else
			error_exit "Manual installation required."
		fi
	else
		error_exit "Unsupported OS for auto-install. Please install manually: ${MISSING_ARRAY[*]}"
	fi
fi

for template in template.default.yml template.docker.env; do
	if [ ! -f "$template" ]; then error_exit "$template missing. Ensure you are in the Misskey root directory."; fi
done

if [ -f "default.yml" ] || [ -f "docker.env" ]; then
	warning "Existing configuration files found."
	read -rp "Overwrite current configurations? (y/N): " -n 1
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		info "Setup aborted by user."
		exit 0
	fi
fi

info "Generating secure credentials..."
MISSKEY_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
MEILI_KEY=$(generate_api_key)
success "Credentials generated."

info "Cloudflare Tunnel configuration..."
while true; do
	read -rp "Enter Cloudflare Tunnel Token (Full command or raw token): " token_input
	if [ -z "$token_input" ]; then
		warning "Token is required."
		continue
	fi
	if [[ $token_input == *"service install"* ]]; then
		CLOUDFLARED_TOKEN=${token_input##*service install }
	else
		CLOUDFLARED_TOKEN=$token_input
	fi
	success "Token processed."
	break
done

ANUBIS_ENABLED=false
ANUBIS_ROBOTS_TXT=false
read -rp "Enable Anubis bot protection? (y/N): " -n 1
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	ANUBIS_ENABLED=true
	info "Anubis enabled. External traffic will be strictly routed through Anubis."
	read -rp "Deploy 'Disallow all' robots.txt? (y/N): " -n 1
	echo
	[[ $REPLY =~ ^[Yy]$ ]] && ANUBIS_ROBOTS_TXT=true
else
	info "Anubis disabled. Direct access to web service port 3000 will be permitted."
fi

read -rp "Target Domain (e.g., misskey.example.com) [Empty for localhost]: " DOMAIN
if [ -z "$DOMAIN" ]; then
	MISSKEY_URL="http://localhost:3000"
else
	MISSKEY_URL="https://$DOMAIN"
fi

info "Applying configuration to YAML and Environment files..."
cp template.default.yml default.yml
cp template.compose.yml compose.yml
cp template.docker.env docker.env

sed -i "s|https://your.host|$MISSKEY_URL|g" default.yml
sed -i "s|PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|$MISSKEY_PASSWORD|g" default.yml
sed -i "s|pass: $MISSKEY_PASSWORD|pass: $POSTGRES_PASSWORD|g" default.yml
sed -i "s|apiKey: $MISSKEY_PASSWORD|apiKey: $MEILI_KEY|g" default.yml

sed -i "s|PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|$POSTGRES_PASSWORD|g" docker.env
sed -i "s|https://your.host|$MISSKEY_URL|g" docker.env
sed -i "s|MEILI_MASTER_KEY=PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|MEILI_MASTER_KEY=$MEILI_KEY|g" docker.env

if grep -q "MEILI_MASTER_KEY: PLEASE_CHANGE_HERE_FOR_SECURITY_REASON" compose.yml; then
	sed -i "s|MEILI_MASTER_KEY: PLEASE_CHANGE_HERE_FOR_SECURITY_REASON|MEILI_MASTER_KEY: $MEILI_KEY|g" compose.yml
fi
success "Configuration files updated."

mkdir -p files db meili_data
success "Data directories initialized."

if [ "$ANUBIS_ENABLED" = true ]; then
	info "Configuring Anubis service..."
	if [ -f "template.anubis.env" ]; then
		cp template.anubis.env anubis.env
		[ "$ANUBIS_ROBOTS_TXT" = true ] && sed -i 's/^# SERVE_ROBOTS_TXT=true/SERVE_ROBOTS_TXT=true/' anubis.env

		sed -i '/^#  anubis:/,/^#      - internal_network$/ { /^#      - internal_network$/ { s/^#//; b }; s/^#// }' compose.yml
		sed -i '/^  anubis:/,/^    networks:/ { /^    ports:/,/^      - 3000:8923/ d }' compose.yml
		sed -i '/^  web:/,/^    networks:/ { /^    ports:/,/^      - 3000:8080/ d }' compose.yml
		sed -i 's|^#    volumes:|    volumes:|' compose.yml
		sed -i 's|^#      - \./bot_policy.yaml:/data/cfg/botPolicy.yaml:ro|      - ./botPolicy.yaml:/data/cfg/botPolicy.yaml:ro|' compose.yml
		success "Anubis integrated into compose.yml."
	else
		warning "template.anubis.env missing. Anubis setup skipped."
		ANUBIS_ENABLED=false
	fi
fi

info "Configuring Cloudflare Tunnel service..."
echo "TUNNEL_TOKEN=$CLOUDFLARED_TOKEN" >tunnel.env
sed -i '/^#cloudflared:/,/^#      - internal_network$/ { s/^#cloudflared:/  cloudflared:/; /^#cloudflared:/ ! s/^#// }' compose.yml
success "Tunnel environment created."

chmod 777 files 2>/dev/null || warning "Could not adjust permissions for 'files/' directory."
chmod +x scripts/*.sh 2>/dev/null

info "Launching Docker containers..."
if docker compose up -d; then
	success "Containers started."

	info "Verifying Tunnel status..."
	for i in {1..30}; do
		if docker compose logs cloudflared --tail=20 2>/dev/null | grep -qi "established\|connected\|ready\|registered"; then
			success "Cloudflare Tunnel connection established."
			break
		fi
		[ $i -eq 30 ] && warning "Tunnel connection status uncertain. Please check 'docker compose logs cloudflared'."
		sleep 1
	done

	echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
	echo -e "Misskey URL: ${BLUE}$MISSKEY_URL${NC}"
	echo -e "Initial Password: ${YELLOW}$MISSKEY_PASSWORD${NC}\n"

	echo -e "${RED}! Note: Cloudflare tunnel action suggested !${NC}"
	echo "Go to Zero Trust > Networks > Connectors, select your tunnel, and edit 'Public Hostnames':"
	if [ "$ANUBIS_ENABLED" = true ]; then
		echo -e "  - Service Type: ${GREEN}HTTP${NC}"
		echo -e "  - URL: ${GREEN}anubis:8923${NC}"
		echo "  (Traffic: Cloudflare -> Anubis (Filter) -> Misskey)"
	else
		echo -e "  - Service Type: ${GREEN}HTTP${NC}"
		echo -e "  - URL: ${GREEN}web:8080${NC}"
		echo "  (Traffic: Cloudflare -> Misskey)"
	fi
	echo "-------------------------------------------------------"
else
	error_exit "Docker Compose failed to start services."
fi
