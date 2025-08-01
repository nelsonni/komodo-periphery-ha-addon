#!/bin/bash

# Komodo Periphery Home Assistant Add-on Installation Script
# Supports Linux, macOS, and Windows (via WSL/Git Bash)
# Usage: ./install.sh [--dev|--production]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
export ADDON_NAME="komodo-periphery-ha"  # Export since it's used in functions
ADDON_SLUG="komodo_periphery-ha"
REPO_NAME="komodo-periphery-ha-addon"
HA_ADDONS_DIR=""
DEV_MODE=false
PRODUCTION_MODE=false

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
    echo -e "${BLUE}Detected OS: ${OS}${NC}"
}

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  Komodo Periphery HA Add-on Installer"
    echo "=============================================="
    echo -e "${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dependencies based on OS
install_dependencies() {
    print_status "Installing dependencies..."

    case $OS in
        "linux")
            # Detect Linux distribution
            if command_exists apt-get; then
                print_status "Installing dependencies via apt..."
                sudo apt-get update
                sudo apt-get install -y git curl docker.io docker-compose jq

                # Add user to docker group
                sudo usermod -aG docker "$USER"
                print_warning "You may need to log out and back in for Docker group changes to take effect"

            elif command_exists yum; then
                print_status "Installing dependencies via yum..."
                sudo yum update -y
                sudo yum install -y git curl docker docker-compose jq
                sudo systemctl enable docker
                sudo systemctl start docker
                sudo usermod -aG docker "$USER"

            elif command_exists pacman; then
                print_status "Installing dependencies via pacman..."
                sudo pacman -Syu --noconfirm git curl docker docker-compose jq
                sudo systemctl enable docker
                sudo systemctl start docker
                sudo usermod -aG docker "$USER"

            else
                print_error "Unsupported Linux distribution. Please install git, curl, docker, docker-compose, and jq manually."
                exit 1
            fi
            ;;

        "macos")
            if command_exists brew; then
                print_status "Installing dependencies via Homebrew..."
                brew install git curl jq

                # Check if Docker Desktop is installed
                if ! command_exists docker; then
                    print_warning "Docker Desktop not found. Please install Docker Desktop for Mac from:"
                    print_warning "https://docs.docker.com/desktop/install/mac-install/"
                    print_warning "Or install via Homebrew: brew install --cask docker"
                fi
            else
                print_error "Homebrew not found. Please install Homebrew first:"
                print_error "https://brew.sh/"
                exit 1
            fi
            ;;

        "windows")
            print_warning "Windows detected. Ensure you have the following installed:"
            print_warning "- Git for Windows (includes Git Bash)"
            print_warning "- Docker Desktop for Windows"
            print_warning "- WSL2 (recommended for development)"

            if ! command_exists git; then
                print_error "Git not found. Please install Git for Windows."
                exit 1
            fi

            if ! command_exists docker; then
                print_error "Docker not found. Please install Docker Desktop for Windows."
                exit 1
            fi
            ;;

        *)
            print_error "Unsupported operating system: $OSTYPE"
            exit 1
            ;;
    esac
}

# Find Home Assistant configuration directory
find_ha_config() {
    print_status "Looking for Home Assistant configuration directory..."

    # Common paths for different setups
    local ha_paths=(
        "$HOME/.homeassistant"
        "$HOME/homeassistant"
        "/usr/share/hassio/homeassistant"
        "/config"
        "$HOME/Documents/HomeAssistant"
        "$HOME/Development/homeassistant"
    )

    # Check if user provided a custom path
    if [[ -n "$HA_CONFIG_PATH" ]]; then
        ha_paths=("$HA_CONFIG_PATH" "${ha_paths[@]}")
    fi

    for path in "${ha_paths[@]}"; do
        if [[ -f "$path/configuration.yaml" ]]; then
            HA_CONFIG_DIR="$path"
            HA_ADDONS_DIR="$path/addons"
            print_status "Found Home Assistant config at: $HA_CONFIG_DIR"
            return 0
        fi
    done

    # If not found, ask user
    print_warning "Home Assistant configuration directory not found automatically."
    echo -n "Please enter the path to your Home Assistant config directory: "
    read -r user_path

    if [[ -f "$user_path/configuration.yaml" ]]; then
        HA_CONFIG_DIR="$user_path"
        HA_ADDONS_DIR="$user_path/addons"
        print_status "Using Home Assistant config at: $HA_CONFIG_DIR"
    else
        print_error "Invalid Home Assistant configuration directory."
        exit 1
    fi
}

# Setup VS Code devcontainer for HA add-on development
setup_devcontainer() {
    print_status "Setting up VS Code devcontainer for Home Assistant add-on development..."

    local devcontainer_dir=".devcontainer"
    mkdir -p "$devcontainer_dir"

    # Create devcontainer.json
    cat > "$devcontainer_dir/devcontainer.json" << 'EOF'
{
  "name": "Home Assistant Add-on Development",
  "image": "ghcr.io/home-assistant/devcontainer:addons",
  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
  "mounts": [
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ],
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/git:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode.vscode-json",
        "redhat.vscode-yaml",
        "ms-vscode.vscode-docker",
        "esbenp.prettier-vscode",
        "bradlc.vscode-tailwindcss"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
          "source.organizeImports": true
        }
      }
    }
  },
  "postCreateCommand": "sudo chmod +x install.sh && ./install.sh --dev",
  "remoteUser": "vscode"
}
EOF

    print_status "Devcontainer configuration created."
}

# Create local development environment
setup_local_dev() {
    print_status "Setting up local development environment..."

    # Create addons directory if it doesn't exist
    mkdir -p "$HA_ADDONS_DIR"

    # Create symlink or copy addon to HA addons directory
    local addon_target="$HA_ADDONS_DIR/$ADDON_SLUG"

    if [[ -L "$addon_target" ]]; then
        print_warning "Addon symlink already exists, removing..."
        rm "$addon_target"
    elif [[ -d "$addon_target" ]]; then
        print_warning "Addon directory already exists, backing up..."
        mv "$addon_target" "${addon_target}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Create symlink (preferred for development)
    if ln -sf "$(pwd)" "$addon_target" 2>/dev/null; then
        print_status "Created symlink: $addon_target -> $(pwd)"
    else
        # Fallback to copying files (Windows without admin rights)
        print_warning "Cannot create symlink, copying files instead..."
        cp -r . "$addon_target"
        print_status "Copied addon files to: $addon_target"
    fi
}

# Build addon locally for testing
build_addon() {
    print_status "Building addon Docker image..."

    # Build for current architecture
    local arch=""
    case $(uname -m) in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="aarch64" ;;
        armv7l) arch="armv7" ;;
        *)
            print_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac

    local image_name="ghcr.io/home-assistant/$ADDON_SLUG-$arch:latest"

    if command_exists docker; then
        print_status "Building Docker image: $image_name"
        docker build --build-arg BUILD_ARCH="$arch" -t "$image_name" .
        print_status "Build completed successfully!"
    else
        print_error "Docker not available. Please install Docker to build the addon."
        exit 1
    fi
}

# Setup production deployment
setup_production() {
    print_status "Setting up production deployment..."

    # Create build configuration
    cat > "build.yaml" << EOF
build_from:
  aarch64: ghcr.io/home-assistant/alpine-base:3.21
  amd64: ghcr.io/home-assistant/alpine-base:3.21
  armhf: ghcr.io/home-assistant/alpine-base:3.21
  armv7: ghcr.io/home-assistant/alpine-base:3.21
  i386: ghcr.io/home-assistant/alpine-base:3.21
labels:
  org.opencontainers.image.title: "Komodo Periphery"
  org.opencontainers.image.description: "Komodo Periphery agent for Home Assistant OS monitoring"
  org.opencontainers.image.source: "https://github.com/your-username/$REPO_NAME"
  org.opencontainers.image.licenses: "MIT"
args:
  KOMODO_VERSION: "latest"
codenotary: "your-email@example.com"
EOF

    # Create GitHub Actions workflow
    mkdir -p ".github/workflows"
    cat > ".github/workflows/builder.yaml" << 'EOF'
name: Builder

env:
  BUILD_ARGS: "--test"
  MONITORED_FILES: "build.yaml config.yaml Dockerfile rootfs"

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  init:
    runs-on: ubuntu-latest
    name: Initialize builds
    outputs:
      changed_addons: ${{ steps.changed_addons.outputs.addons }}
      changed: ${{ steps.changed_addons.outputs.changed }}
    steps:
      - name: Check out the repository
        uses: actions/checkout@v4

      - name: Get changed files
        id: changed_files
        uses: jitterbit/get-changed-files@v1

      - name: Find add-on directories
        id: changed_addons
        run: |
          declare -a changed_addons
          for file in ${{ steps.changed_files.outputs.all }}; do
            if [[ $file =~ $MONITORED_FILES ]]; then
              changed_addons+=("komodo_periphery")
              break
            fi
          done

          changed=$(printf "%s\n" "${changed_addons[@]}" | jq -R -s -c 'split("\n")[:-1]')
          echo "changed=$changed" >> $GITHUB_OUTPUT
          echo "addons=$changed" >> $GITHUB_OUTPUT

  build:
    runs-on: ubuntu-latest
    name: Build ${{ matrix.addon }} add-on
    needs:
      - init
    if: needs.init.outputs.changed == 'true'
    strategy:
      matrix:
        addon: ${{ fromJson(needs.init.outputs.changed_addons) }}
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Get information
        id: info
        uses: home-assistant/actions/helpers/info@master
        with:
          path: "./${{ matrix.addon }}"

      - name: Check if add-on should be built
        id: check
        run: |
          if [[ "${{ steps.info.outputs.architectures }}" =~ ${{ matrix.arch }} ]]; then
             echo "build_arch=true" >> $GITHUB_OUTPUT
             echo "image=$(echo ${{ steps.info.outputs.image }} | cut -d'/' -f3)" >> $GITHUB_OUTPUT
             if [[ -z "${{ github.head_ref }}" ]] && [[ "${{ github.event_name }}" == "push" ]]; then
                 echo "BUILD_ARGS=" >> $GITHUB_ENV
             fi
           else
             echo "${{ matrix.arch }} is not a valid arch for ${{ matrix.addon }}, skipping build"
             echo "build_arch=false" >> $GITHUB_OUTPUT
          fi

      - name: Login to GitHub Container Registry
        if: env.BUILD_ARGS != '--test'
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.repository_owner }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build ${{ matrix.addon }} add-on
        if: steps.check.outputs.build_arch == 'true'
        uses: home-assistant/builder@2024.03.5
        with:
          args: |
            ${{ env.BUILD_ARGS }} \
            --${{ matrix.arch }} \
            --target /data/${{ matrix.addon }} \
            --image "${{ steps.check.outputs.image }}" \
            --docker-hub "ghcr.io/${{ github.repository_owner }}" \
            --addon
EOF

    print_status "Production deployment files created."
}

# Create project documentation
create_documentation() {
    print_status "Creating development documentation..."

    cat > "DEVELOPMENT.md" << 'EOF'
# Komodo Periphery Add-on Development

## Development Setup

### Prerequisites
- Docker and Docker Compose
- Home Assistant development environment
- Visual Studio Code (recommended)

### Local Development
1. Clone this repository
2. Run `./install.sh --dev` to set up the development environment
3. Open in VS Code and use the devcontainer for consistent development environment

### Testing
- Use the Home Assistant Supervisor for local testing
- Build locally with: `docker build -t komodo-periphery .`
- Test configuration changes in the add-on UI

### Directory Structure
```
komodo_periphery/
├── config.yaml              # Add-on configuration
├── Dockerfile               # Container definition
├── README.md                # User documentation
├── DEVELOPMENT.md           # This file
├── icon.svg                 # Add-on icon
├── rootfs/                  # Container filesystem
│   └── etc/services.d/
│       └── komodo-periphery/
│           ├── run          # Service run script
│           └── finish       # Service finish script
├── translations/            # UI translations
│   └── en.yaml
├── .devcontainer/           # VS Code devcontainer
│   └── devcontainer.json
└── .github/workflows/       # CI/CD
    └── builder.yaml
```

### Making Changes
1. Modify configuration in `config.yaml`
2. Update service scripts in `rootfs/etc/services.d/komodo-periphery/`
3. Test locally using Home Assistant Supervisor
4. Submit pull request

### Building Multi-Architecture Images
The GitHub Actions workflow automatically builds for all supported architectures when pushing to the main branch.

### Debugging
- Check add-on logs in Home Assistant Supervisor
- Use `docker logs` for container-level debugging
- Enable debug logging in the add-on configuration
EOF

    print_status "Development documentation created."
}

# Main installation function
main() {
    print_header

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dev)
                DEV_MODE=true
                shift
                ;;
            --production)
                PRODUCTION_MODE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--dev|--production]"
                echo "  --dev         Set up development environment"
                echo "  --production  Set up production deployment files"
                exit 0
                ;;
            *)
                print_error "Unknown parameter: $1"
                exit 1
                ;;
        esac
    done

    # If no mode specified, default to dev
    if [[ "$DEV_MODE" == false && "$PRODUCTION_MODE" == false ]]; then
        DEV_MODE=true
    fi

    detect_os
    install_dependencies

    if [[ "$DEV_MODE" == true ]]; then
        print_status "Setting up development environment..."
        find_ha_config
        setup_devcontainer
        setup_local_dev
        build_addon
        create_documentation

        print_status "Development setup complete!"
        print_status "You can now:"
        print_status "1. Open this project in VS Code"
        print_status "2. Use the devcontainer for development"
        print_status "3. Find the add-on in Home Assistant Supervisor -> Add-on Store -> Local add-ons"

    elif [[ "$PRODUCTION_MODE" == true ]]; then
        print_status "Setting up production deployment..."
        setup_production
        create_documentation

        print_status "Production setup complete!"
        print_status "1. Update the repository URL in build.yaml and GitHub workflow"
        print_status "2. Commit and push to GitHub to trigger automated builds"
        print_status "3. Users can install from your repository"
    fi

    print_status "Installation completed successfully!"
}

# Run main function
main "$@"
