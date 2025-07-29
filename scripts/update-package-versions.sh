#!/bin/bash
# Script to help update package versions in Dockerfile
# Usage: ./scripts/update-package-versions.sh

set -e

echo "🔍 Checking current Alpine package versions..."
echo "================================================"

# Base image for checking (use same as Dockerfile)
BASE_IMAGE="ghcr.io/hassio-addons/base-amd64:latest"

# Packages to check
PACKAGES=(
    "bash"
    "curl"
    "docker-cli"
    "openssl"
    "procps-ng"
)

echo "Using base image: $BASE_IMAGE"
echo ""

# Function to get package version
get_package_version() {
    local package=$1
    echo "Checking $package..."

    # Run apk search in the container to get available versions
    docker run --rm "$BASE_IMAGE" sh -c "apk search '$package' | grep '^$package-[0-9]' | head -5" || {
        echo "  ❌ Failed to check $package"
        return 1
    }
    echo ""
}

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker is required but not available"
    exit 1
fi

# Pull the base image to ensure we have the latest
echo "📥 Pulling base image..."
docker pull "$BASE_IMAGE" || {
    echo "❌ Failed to pull base image"
    exit 1
}

echo ""

# Check each package
for package in "${PACKAGES[@]}"; do
    get_package_version "$package"
done

echo "📝 Manual Update Instructions:"
echo "=============================="
echo "1. Update the package versions in Dockerfile"
echo "2. Test the build: docker build -t test-image ."
echo "3. Verify packages: docker run --rm test-image apk list --installed"
echo "4. Update this script with new package versions if needed"
echo ""
echo "💡 Tip: You can also check package versions at:"
echo "   https://pkgs.alpinelinux.org/packages"
echo ""
echo "⚠️  Remember: Always test builds after updating package versions!"
