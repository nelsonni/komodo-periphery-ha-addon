#!/bin/bash
# Development tools installation script for Komodo Periphery Add-on devcontainer

set -e

echo "🔧 Installing development tools for Komodo Periphery Add-on..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to safely run apt commands
safe_apt() {
    if command_exists apt-get; then
        sudo apt-get "$@" || {
            echo "⚠️ apt-get command failed, but continuing..."
            return 0
        }
    else
        echo "⚠️ apt-get not available, skipping package installation"
        return 0
    fi
}

# Function to safely install with curl
safe_curl_install() {
    local url="$1"
    local target="$2"
    local name="$3"
    
    if command_exists curl; then
        echo "📥 Installing $name..."
        curl -fsSL "$url" -o "$target" || {
            echo "⚠️ Failed to download $name, skipping..."
            return 0
        }
    else
        echo "⚠️ curl not available, skipping $name installation"
        return 0
    fi
}

# Update package lists (with error handling)
echo "📦 Updating package lists..."
safe_apt update

# Install system dependencies
echo "📦 Installing system packages..."
safe_apt install -y \
    curl \
    wget \
    jq \
    unzip \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    git \
    bash \
    bc || echo "⚠️ Some system packages may not have been installed"

# Install hadolint (Dockerfile linter) - with error handling
echo "🐳 Installing hadolint..."
if command_exists curl && command_exists jq; then
    HADOLINT_VERSION=$(curl -s https://api.github.com/repos/hadolint/hadolint/releases/latest | jq -r .tag_name 2>/dev/null || echo "v2.12.0")
    safe_curl_install \
        "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
        "/tmp/hadolint" \
        "hadolint"
    
    if [ -f "/tmp/hadolint" ]; then
        sudo install /tmp/hadolint /usr/local/bin/hadolint 2>/dev/null || {
            echo "⚠️ Could not install hadolint to /usr/local/bin, trying alternative location..."
            mkdir -p ~/.local/bin
            install /tmp/hadolint ~/.local/bin/hadolint || echo "⚠️ Failed to install hadolint"
        }
        rm -f /tmp/hadolint
    fi
else
    echo "⚠️ Skipping hadolint installation (curl or jq not available)"
fi

# Install shellcheck (Shell script linter)
echo "🐚 Installing shellcheck..."
safe_apt install -y shellcheck || echo "⚠️ Could not install shellcheck via apt"

# Install yamllint (YAML linter) - via pip if available
echo "📄 Installing yamllint..."
if command_exists pip3; then
    pip3 install yamllint --user || echo "⚠️ Could not install yamllint via pip"
elif command_exists pip; then
    pip install yamllint --user || echo "⚠️ Could not install yamllint via pip"
else
    echo "⚠️ pip not available, skipping yamllint installation"
fi

# Install Home Assistant CLI - via pip if available
echo "🏠 Installing Home Assistant CLI..."
if command_exists pip3; then
    pip3 install homeassistant-cli --user || echo "⚠️ Could not install Home Assistant CLI"
elif command_exists pip; then
    pip install homeassistant-cli --user || echo "⚠️ Could not install Home Assistant CLI"
fi

# Install add-on linter - via npm if available
echo "🔍 Installing Home Assistant Add-on linter..."
if command_exists npm; then
    npm install -g @home-assistant/cli || echo "⚠️ Could not install HA CLI via npm"
else
    echo "⚠️ npm not available, skipping add-on linter installation"
fi

# Install Trivy (Security scanner) - with error handling
echo "🛡️ Installing Trivy..."
if command_exists curl; then
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin 2>/dev/null || {
        echo "⚠️ Could not install Trivy via script, trying alternative..."
        # Try alternative installation
        if command_exists wget; then
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add - 2>/dev/null || echo "⚠️ Could not add Trivy repo key"
            echo "deb https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list >/dev/null || echo "⚠️ Could not add Trivy repo"
            safe_apt update
            safe_apt install -y trivy || echo "⚠️ Could not install Trivy via apt"
        fi
    }
else
    echo "⚠️ curl not available, skipping Trivy installation"
fi

# Install goss (Server testing) - with error handling
echo "🧪 Installing goss..."
if command_exists curl && command_exists jq; then
    GOSS_VERSION=$(curl -s https://api.github.com/repos/aelsabbahy/goss/releases/latest | jq -r .tag_name 2>/dev/null || echo "v0.4.4")
    safe_curl_install \
        "https://github.com/aelsabbahy/goss/releases/download/${GOSS_VERSION}/goss-linux-amd64" \
        "/tmp/goss" \
        "goss"
    
    if [ -f "/tmp/goss" ]; then
        sudo install /tmp/goss /usr/local/bin/goss 2>/dev/null || {
            mkdir -p ~/.local/bin
            install /tmp/goss ~/.local/bin/goss || echo "⚠️ Failed to install goss"
        }
        rm -f /tmp/goss
    fi
fi

# Install dive (Docker image analyzer) - with error handling
echo "🔍 Installing dive..."
if command_exists curl && command_exists jq; then
    DIVE_VERSION=$(curl -s https://api.github.com/repos/wagoodman/dive/releases/latest | jq -r .tag_name 2>/dev/null || echo "v0.12.0")
    safe_curl_install \
        "https://github.com/wagoodman/dive/releases/download/${DIVE_VERSION}/dive_${DIVE_VERSION#v}_linux_amd64.deb" \
        "/tmp/dive.deb" \
        "dive"
    
    if [ -f "/tmp/dive.deb" ]; then
        sudo dpkg -i /tmp/dive.deb 2>/dev/null || echo "⚠️ Could not install dive via dpkg"
        rm -f /tmp/dive.deb
    fi
fi

# Install ctop (Container monitoring) - with error handling
echo "📊 Installing ctop..."
safe_curl_install \
    "https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-amd64" \
    "/tmp/ctop" \
    "ctop"

if [ -f "/tmp/ctop" ]; then
    sudo install /tmp/ctop /usr/local/bin/ctop 2>/dev/null || {
        mkdir -p ~/.local/bin
        install /tmp/ctop ~/.local/bin/ctop || echo "⚠️ Failed to install ctop"
        chmod +x ~/.local/bin/ctop 2>/dev/null || true
    }
    rm -f /tmp/ctop
fi

# Install lazydocker (Docker TUI) - with error handling
echo "🐋 Installing lazydocker..."
if command_exists curl && command_exists jq; then
    LAZYDOCKER_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | jq -r .tag_name 2>/dev/null || echo "v0.23.1")
    safe_curl_install \
        "https://github.com/jesseduffield/lazydocker/releases/download/${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION#v}_Linux_x86_64.tar.gz" \
        "/tmp/lazydocker.tar.gz" \
        "lazydocker"
    
    if [ -f "/tmp/lazydocker.tar.gz" ]; then
        tar xf /tmp/lazydocker.tar.gz -C /tmp 2>/dev/null || echo "⚠️ Could not extract lazydocker"
        if [ -f "/tmp/lazydocker" ]; then
            sudo install /tmp/lazydocker /usr/local/bin/lazydocker 2>/dev/null || {
                mkdir -p ~/.local/bin
                install /tmp/lazydocker ~/.local/bin/lazydocker || echo "⚠️ Failed to install lazydocker"
            }
        fi
        rm -f /tmp/lazydocker*
    fi
fi

# Check docker-compose (usually pre-installed in HA devcontainer)
echo "🔗 Checking docker-compose..."
if ! command_exists docker-compose; then
    echo "📥 Installing docker-compose..."
    if command_exists curl && command_exists jq; then
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name 2>/dev/null || echo "v2.24.1")
        safe_curl_install \
            "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
            "/tmp/docker-compose" \
            "docker-compose"
        
        if [ -f "/tmp/docker-compose" ]; then
            sudo install /tmp/docker-compose /usr/local/bin/docker-compose 2>/dev/null || {
                mkdir -p ~/.local/bin
                install /tmp/docker-compose ~/.local/bin/docker-compose || echo "⚠️ Failed to install docker-compose"
                chmod +x ~/.local/bin/docker-compose 2>/dev/null || true
            }
            rm -f /tmp/docker-compose
        fi
    fi
else
    echo "✅ docker-compose already available"
fi

# Install act (GitHub Actions local runner) - with error handling
echo "🎭 Installing act..."
if command_exists curl && command_exists jq; then
    ACT_VERSION=$(curl -s https://api.github.com/repos/nektos/act/releases/latest | jq -r .tag_name 2>/dev/null || echo "v0.2.54")
    safe_curl_install \
        "https://github.com/nektos/act/releases/download/${ACT_VERSION}/act_Linux_x86_64.tar.gz" \
        "/tmp/act.tar.gz" \
        "act"
    
    if [ -f "/tmp/act.tar.gz" ]; then
        tar xf /tmp/act.tar.gz -C /tmp 2>/dev/null || echo "⚠️ Could not extract act"
        if [ -f "/tmp/act" ]; then
            sudo install /tmp/act /usr/local/bin/act 2>/dev/null || {
                mkdir -p ~/.local/bin
                install /tmp/act ~/.local/bin/act || echo "⚠️ Failed to install act"
            }
        fi
        rm -f /tmp/act*
    fi
fi

# Install just (Command runner) - with error handling
echo "⚡ Installing just..."
if command_exists curl; then
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | sudo bash -s -- --to /usr/local/bin 2>/dev/null || {
        echo "⚠️ Could not install just via script, trying alternative..."
        mkdir -p ~/.local/bin
        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin 2>/dev/null || echo "⚠️ Failed to install just"
    }
fi

# Ensure ~/.local/bin exists and is in PATH
mkdir -p ~/.local/bin

# Set up useful aliases (safely)
echo "🔗 Setting up aliases..."
if [ -f ~/.bashrc ]; then
    BASHRC_FILE=~/.bashrc
elif [ -f ~/.bash_profile ]; then
    BASHRC_FILE=~/.bash_profile
else
    BASHRC_FILE=~/.profile
    touch "$BASHRC_FILE"
fi

# Only add aliases if they don't exist
if ! grep -q "# Komodo Periphery development aliases" "$BASHRC_FILE" 2>/dev/null; then
cat >> "$BASHRC_FILE" << 'EOF'

# Komodo Periphery development aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dimg='docker images'
alias dlog='docker logs'
alias dexec='docker exec -it'

# Komodo development aliases
alias kbuild='make build'
alias ktest='make test'
alias kdev='make dev'
alias klint='make lint'
alias kclean='make clean'
alias kinfo='make info'
alias kstatus='make status'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

# Quick navigation
alias workspace='cd /workspaces'
alias addon="cd /workspaces/\${ADDON_SLUG:-komodo_periphery}"

# Development utilities
alias python='python3'
alias pip='pip3'
alias serve='python -m http.server'
alias json='jq'
alias yaml='yamllint'

EOF
fi

# Create development scripts directory
mkdir -p ~/.local/bin

# Create useful development scripts (with error handling)
if [ ! -f ~/.local/bin/addon-test ]; then
cat > ~/.local/bin/addon-test << 'EOF'
#!/bin/bash
# Quick add-on testing script
echo "🧪 Running quick add-on tests..."
if command -v make >/dev/null 2>&1; then
    make lint-addon || echo "⚠️ lint-addon failed"
    make test-config || echo "⚠️ test-config failed"
    make test-build || echo "⚠️ test-build failed"
else
    echo "⚠️ make not available, running direct commands..."
    if command -v pytest >/dev/null 2>&1; then
        pytest tests/ -m "not integration and not slow" || echo "⚠️ pytest failed"
    fi
fi
echo "✅ Quick tests completed"
EOF
chmod +x ~/.local/bin/addon-test 2>/dev/null || true
fi

if [ ! -f ~/.local/bin/addon-logs ]; then
cat > ~/.local/bin/addon-logs << 'EOF'
#!/bin/bash
# Quick log viewer for development
if docker ps | grep -q komodo-periphery-dev; then
    docker logs -f komodo-periphery-dev
else
    echo "❌ Development container not running. Use 'make dev' to start."
fi
EOF
chmod +x ~/.local/bin/addon-logs 2>/dev/null || true
fi

if [ ! -f ~/.local/bin/addon-shell ]; then
cat > ~/.local/bin/addon-shell << 'EOF'
#!/bin/bash
# Quick shell access to development container
if docker ps | grep -q komodo-periphery-dev; then
    docker exec -it komodo-periphery-dev /bin/bash
else
    echo "❌ Development container not running. Use 'make dev' to start."
fi
EOF
chmod +x ~/.local/bin/addon-shell 2>/dev/null || true
fi

# Add local bin to PATH if not already there
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$BASHRC_FILE" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC_FILE"
fi

# Create development configuration
mkdir -p ~/.config/komodo-periphery

if [ ! -f ~/.config/komodo-periphery/dev-config.yaml ]; then
cat > ~/.config/komodo-periphery/dev-config.yaml << 'EOF'
# Development configuration for Komodo Periphery Add-on
development:
  auto_reload: true
  debug_mode: true
  verbose_logging: true
  
testing:
  mock_komodo_server: true
  use_test_data: true
  skip_auth: false

build:
  cache_builds: true
  parallel_builds: true
  target_arch: amd64
EOF
fi

# Clean up (safely)
safe_apt autoremove -y || echo "⚠️ Could not run autoremove"
safe_apt autoclean || echo "⚠️ Could not run autoclean"

echo "✅ Development tools installation completed!"
echo ""
echo "🚀 Available tools:"
echo "   - hadolint (Dockerfile linter)"
echo "   - shellcheck (Shell script linter)"
echo "   - yamllint (YAML linter)"
echo "   - trivy (Security scanner)"
echo "   - goss (Server testing)"
echo "   - dive (Docker image analyzer)"
echo "   - ctop (Container monitoring)"
echo "   - lazydocker (Docker TUI)"
echo "   - act (GitHub Actions local runner)"
echo "   - just (Command runner)"
echo ""
echo "🔗 Useful aliases added to $BASHRC_FILE"
echo "📁 Development scripts added to ~/.local/bin"
echo ""
echo "💡 Try running 'make help' to see available development commands"
echo "🔄 You may need to run 'source $BASHRC_FILE' or restart your shell to use new aliases"