#!/bin/bash
# Additional tools setup script for Komodo Periphery Add-on devcontainer
# Run this after the devcontainer is fully set up to install additional packages

set -e

echo "🔧 Installing additional development tools..."

# Function to safely install pip packages
safe_pip_install() {
    local package="$1"
    local description="$2"
    
    echo "📦 Installing $description..."
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user "$package" || {
            echo "⚠️ Failed to install $package via pip3, trying pip..."
            if command -v pip >/dev/null 2>&1; then
                pip install --user "$package" || echo "⚠️ Failed to install $package"
            fi
        }
    elif command -v pip >/dev/null 2>&1; then
        pip install --user "$package" || echo "⚠️ Failed to install $package"
    else
        echo "⚠️ pip not available, skipping $description"
    fi
}

# Install additional testing tools
echo "🧪 Installing advanced testing packages..."
safe_pip_install "testcontainers>=3.7.0" "testcontainers (for container testing)"
safe_pip_install "pytest-docker>=2.0.0" "pytest-docker (for Docker integration testing)"
safe_pip_install "mypy>=1.5.0" "mypy (for type checking)"

# Install Home Assistant specific tools
echo "🏠 Installing Home Assistant testing utilities..."
safe_pip_install "home-assistant-chip-core>=2023.8.0" "Home Assistant CHIP core testing utilities"

# Install advanced development tools
echo "🚀 Installing advanced development tools..."
safe_pip_install "tqdm>=4.66.0" "tqdm (for progress bars)"
safe_pip_install "netifaces>=0.11.0" "netifaces (for network interface detection)"
safe_pip_install "structlog>=23.1.0" "structlog (for structured logging)"
safe_pip_install "watchdog>=3.0.0" "watchdog (for file system monitoring)"
safe_pip_install "asyncio-mqtt>=0.13.0" "asyncio-mqtt (for MQTT testing)"

# Install web development tools
echo "🌐 Installing web development tools..."
safe_pip_install "uvicorn>=0.23.0" "uvicorn (ASGI server)"
safe_pip_install "fastapi>=0.103.0" "fastapi (for API testing)"

# Install documentation tools
echo "📚 Installing documentation tools..."
safe_pip_install "mkdocs>=1.5.0" "mkdocs (for documentation)"
safe_pip_install "mkdocs-material>=9.2.0" "mkdocs-material (documentation theme)"

# Install configuration tools
echo "⚙️ Installing configuration management tools..."
safe_pip_install "configparser>=5.3.0" "configparser (for configuration management)"

# Update Docker Compose to v2 if needed
echo "🐳 Checking Docker Compose version..."
if command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
        echo "✅ Docker Compose v2 available: $COMPOSE_VERSION"
    else
        echo "⚠️ Docker Compose v2 not available via 'docker compose'"
        if command -v docker-compose >/dev/null 2>&1; then
            COMPOSE_VERSION=$(docker-compose version --short 2>/dev/null || echo "unknown")
            echo "📄 Found docker-compose v1: $COMPOSE_VERSION"
            echo "💡 Consider upgrading to Docker Compose v2"
        fi
    fi
else
    echo "⚠️ Docker not available"
fi

# Verify installations
echo "🔍 Verifying installations..."
echo "Python packages:"
pip3 list --user | grep -E "(pytest|docker|yaml|testcontainers|mypy)" || true

echo "System tools:"
command -v hadolint >/dev/null && echo "✅ hadolint" || echo "❌ hadolint"
command -v shellcheck >/dev/null && echo "✅ shellcheck" || echo "❌ shellcheck"
command -v trivy >/dev/null && echo "✅ trivy" || echo "❌ trivy"
command -v yamllint >/dev/null && echo "✅ yamllint" || echo "❌ yamllint"

echo ""
echo "✅ Additional tools setup completed!"
echo ""
echo "💡 To use the newly installed tools, you may need to:"
echo "   - Restart your terminal or run: source ~/.bashrc"
echo "   - Add ~/.local/bin to your PATH if not already done"
echo ""
echo "🚀 You can now run advanced tests with:"
echo "   pytest tests/ -m integration  # Integration tests with containers"
echo "   mypy .                       # Type checking"
echo "   mkdocs serve                 # Documentation server"