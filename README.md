# Misskey Docker Setup

A complete Docker-based Misskey instance setup with automated configuration validation and security checks.

## Requirements

### Host System Requirements

Before running the setup scripts, ensure your host system has the following packages installed:

- **Docker**: Container runtime (required)
- **Docker Compose**: Or `docker compose` plugin (required)
- **OpenSSL**: For generating secure passwords and API keys (required for auto-setup)
- **Bash**: Shell interpreter (required)
- **Basic utilities**: `sed`, `grep`, `mkdir`, `chmod` (usually pre-installed)

### Installation

**Arch Linux:**

```shell
sudo pacman -S docker docker-compose openssl
sudo systemctl enable --now docker
```

**Fedora/RHEL/CentOS (RPM-based):**

```shell
sudo dnf install docker docker-compose openssl
sudo systemctl enable --now docker
```

**Ubuntu/Debian (Debian-based):**

```shell
sudo apt update
sudo apt install docker.io docker-compose openssl
sudo systemctl enable --now docker
```

**Gentoo:**

```shell
sudo emerge app-containers/docker app-containers/docker-compose dev-libs/openssl
sudo rc-update add docker default
sudo rc-service docker start
```

### Verify Installation

```shell
docker --version
docker compose version
openssl version
```

## Quick Start

### Option 1: Auto Setup (Recommended)

After `git clone`, run the auto-setup script:

```shell
./scripts/auto-setup.sh
```

This will automatically:

- Generate secure passwords and API keys
- Configure all settings based on your input
- Validate configuration
- Start Misskey services

### Option 2: Manual Setup

1. **Copy Templates**:

   ```shell
   # Using the copy script (recommended)
   ./scripts/copy.sh

   # Or manually:
   cp template.compose.yml compose.yml
   cp template.default.yml default.yml
   cp template.docker.env docker.env
   cp template.tunnel.env tunnel.env  # Optional (Cloudflare Tunnel)
   cp template.anubis.env anubis.env  # Optional (Bot Protection)
   ```

2. **Configure Settings**:
   Edit `default.yml` and `docker.env` to set your domain and secure passwords

3. **Start with Validation**:

   ```shell
   ./scripts/start-misskey.sh
   ```

4. **Access Misskey**:
   Open `http://localhost:3000` in your browser

## Manual Start

If you prefer to start manually:

```shell
# Validate configuration first
docker compose --profile validate up validate

# Start services
docker compose up -d
```

## Configuration Files

### `default.yml`

Main Misskey configuration. Key settings:

- `url`: Your domain (required)
- `setupPassword`: Admin setup password (required)
- Database and service connections

### `docker.env`

Environment variables for Docker services:

- PostgreSQL credentials
- Misskey configuration
- Meilisearch API key

### `tunnel.env` (Optional)

Cloudflare tunnel token for external access:

- Get token from Cloudflare Zero Trust dashboard
- Copy `template.compose.yml` to `compose.yml`
- Uncomment tunnel service in `compose.yml`

### `anubis.env` (Optional)

Anubis bot protection configuration:

- Protects against bots and scrapers
- Copy `template.compose.yml` to `compose.yml`
- Uncomment anubis service in `compose.yml`
- Comment out `ports` in `web` service (Anubis handles external access)

## Directory Structure

```shell
iasskey/
|-- scripts/
|   |-- auto-setup.sh         # Fully automated setup
|   |-- copy.sh               # Copy template files to config files
|   |-- validate-config.sh    # Configuration validation
|   |-- start-misskey.sh      # Startup with validation
|-- template.compose.yml      # Docker Compose template
|-- compose.yml               # Docker Compose configuration (generated)
|-- default.yml               # Misskey configuration
|-- docker.env                # Environment variables
|-- tunnel.env                # Tunnel configuration (optional)
|-- anubis.env                # Anubis bot protection (optional)
|-- template.*.yml/.env      # Configuration templates
|-- files/                    # User uploaded files
|-- db/                       # PostgreSQL data
|-- meili_data/               # Meilisearch data
```

## Security Validation

The setup includes automated security checks that prevent startup if:

- Default URL `https://your.host` is used
- Default password `PLEASE_CHANGE_HERE_FOR_SECURITY_REASON` is used
- Required configuration files are missing
- Directory permissions are incorrect

## Services

- **web**: Misskey application (port 3000)
- **db**: PostgreSQL database
- **redis**: Redis cache
- **meilisearch**: Search engine
- **validate**: Configuration validation (optional)
- **anubis**: Bot protection proxy (optional)

## Troubleshooting

### Port Conflicts

If port 3000 is in use, change it in `compose.yml` (after copying from template):

```shell
ports:
  - 3001:8080 # Change 3000 to your preferred port
```

### File Permissions

The setup automatically configures permissions, but if issues occur:

```shell
chmod 777 files
```

### Validation Errors

If validation fails, check:

- `default.yml` has your actual domain
- `docker.env` has secure passwords
- All required files exist

## Development

To run validation only:

```shell
docker compose --profile validate up validate
```

To view logs:

```shell
docker compose logs -f web
```

To restart services:

```shell
docker compose restart web
```

## License

This setup configuration is provided as-is. Misskey is licensed under the AGPL-3.0 License.
