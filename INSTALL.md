# Installation Guide

This guide provides multiple installation methods for setting up the Komodo Periphery Home Assistant Add-on development environment across different platforms.

## Quick Start

Choose the installation method that best fits your platform:

### 🐍 Python (Recommended - Cross-Platform)

```bash
python install.py --dev
```

### 🐧 Linux / 🍎 macOS

```bash
chmod +x install.sh
./install.sh --dev
```

### 🪟 Windows PowerShell

```powershell
.\install.ps1 -Dev
```

### 🪟 Windows Batch (Simple)

```cmd
install.bat dev
```

## Installation Options

### Development Mode (Default)

Sets up a complete local development environment:

- Installs required dependencies
- Finds Home Assistant configuration directory
- Creates VS Code devcontainer configuration
- Sets up local add-on development
- Builds Docker images for testing
- Creates development documentation

### Production Mode

Sets up files for production deployment:

- Creates build configuration for multi-architecture support
- Sets up GitHub Actions workflows
- Generates deployment documentation
- Prepares repository for distribution

## Platform-Specific Requirements

### Linux

**Automatic Installation:**

- Detects package manager (apt, yum, dnf, pacman, zypper)
- Installs: git, docker, docker-compose, jq
- Configures Docker service and user permissions

**Manual Prerequisites:**

- sudo access for package installation
- Internet connection for package downloads

### macOS

**Automatic Installation:**

- Uses Homebrew for package management
- Installs: git, docker (if needed), jq
- Checks for Docker Desktop

**Manual Prerequisites:**

- [Homebrew](https://brew.sh/) package manager
- [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
- Xcode Command Line Tools: `xcode-select --install`

### Windows

**Automatic Detection:**

- Checks for required tools
- Provides download links for missing components
- Supports PowerShell, Python, and Git Bash

**Manual Prerequisites:**

- [Git for Windows](https://git-scm.com/download/win)
- [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
- [Python 3.7+](https://python.org/downloads/) (recommended)
- PowerShell 5.1+ (usually pre-installed)

## Installation Scripts

### `install.py` - Python Cross-Platform Installer

- **Advantages:** True cross-platform, rich error handling, colored output
- **Requirements:** Python 3.7+
- **Features:** OS detection, dependency management, automatic fallbacks

```bash
python install.py --dev          # Development setup
python install.py --production   # Production setup
python install.py --help         # Show help
```

### `install.sh` - Bash Installer

- **Advantages:** Native Linux/macOS tool, fast execution, comprehensive
- **Requirements:** Bash shell, sudo access
- **Features:** Package manager detection, Docker configuration, symlink support

```bash
./install.sh --dev              # Development setup
./install.sh --production       # Production setup
./install.sh --help             # Show help
```

### `install.ps1` - PowerShell Installer

- **Advantages:** Native Windows tool, rich Windows integration
- **Requirements:** PowerShell 5.1+, execution policy bypass
- **Features:** Windows-specific checks, Visual Studio Code integration

```powershell
.\install.ps1 -Dev              # Development setup
.\install.ps1 -Production       # Production setup
.\install.ps1 -Help             # Show help
```

### `install.bat` - Windows Batch Wrapper

- **Advantages:** Simple, no prerequisites, automatic detection
- **Requirements:** Windows Command Prompt
- **Features:** Detects and runs the best available installer

```cmd
install.bat                     # Development setup (default)
install.bat production          # Production setup
install.bat help                # Show help
```

## Environment Variables

Set these environment variables to customize installation:

- `HA_CONFIG_PATH` - Custom path to Home Assistant configuration directory
- `DOCKER_HOST` - Custom Docker daemon endpoint (advanced)

### Examples

```bash
# Linux/macOS
export HA_CONFIG_PATH="/custom/path/to/homeassistant"
./install.sh --dev

# Windows PowerShell
$env:HA_CONFIG_PATH="C:\custom\path\to\homeassistant"
.\install.ps1 -Dev

# Windows Command Prompt
set HA_CONFIG_PATH=C:\custom\path\to\homeassistant
install.bat dev
```

## Development Environment

After successful installation, you'll have:

### 📁 Directory Structure

```text
komodo_periphery/
├── config.yaml              # Add-on configuration
├── Dockerfile               # Container definition
├── README.md                # User documentation
├── DEVELOPMENT.md           # Development guide
├── icon.svg                 # Add-on icon
├── rootfs/                  # Container filesystem
├── translations/            # UI translations
├── .devcontainer/           # VS Code devcontainer
├── .github/workflows/       # CI/CD workflows
└── install.*                # Installation scripts
```

### 🔧 VS Code DevContainer

- Pre-configured development environment
- Home Assistant add-on development tools
- Docker-in-Docker support
- Automatic extension installation

### 🐳 Docker Integration

- Local image building and testing
- Multi-architecture support preparation
- Home Assistant Supervisor integration

## Testing Your Installation

### 1. Verify Add-on Installation

```bash
# Check if add-on appears in Home Assistant
# Navigate to: Supervisor → Add-on Store → Local add-ons
```

### 2. Build and Test Docker Image

```bash
docker build -t komodo-periphery-test .
docker run --rm komodo-periphery-test --version
```

### 3. VS Code DevContainer

```bash
# Open project in VS Code
code .

# Use Command Palette (Ctrl+Shift+P)
# Select: "Dev Containers: Reopen in Container"
```

## Troubleshooting

### Common Issues

#### Permission Denied (Linux/macOS)

```bash
chmod +x install.sh
sudo chown $USER:$USER install.sh
```

#### Docker Group Access (Linux)

```bash
sudo usermod -aG docker $USER
# Log out and log back in
```

#### PowerShell Execution Policy (Windows)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Home Assistant Directory Not Found

- Set `HA_CONFIG_PATH` environment variable
- Ensure `configuration.yaml` exists in the directory
- Check directory permissions

#### Docker Desktop Not Running (Windows/macOS)

- Start Docker Desktop application
- Wait for Docker daemon to be ready
- Check Docker Desktop settings

### Debug Mode

Enable verbose output by setting environment variables:

```bash
# Linux/macOS
export DEBUG=1
./install.sh --dev

# Windows
$env:DEBUG=1
.\install.ps1 -Dev
```

### Getting Help

1. **Check logs:** Installation scripts provide detailed error messages
2. **Verify prerequisites:** Ensure all required tools are installed
3. **Check permissions:** Ensure proper file and directory permissions
4. **Review documentation:** Check `DEVELOPMENT.md` for detailed setup instructions
5. **GitHub Issues:** Report bugs or ask questions in the repository issues

## Next Steps

After successful installation:

1. **Open in VS Code:** Use the devcontainer for development
2. **Configure add-on:** Edit `config.yaml` and other configuration files
3. **Test locally:** Use Home Assistant Supervisor to test your add-on
4. **Make changes:** Modify code and test iteratively
5. **Deploy:** Use production mode to prepare for distribution

## Advanced Configuration

### Custom Docker Registry

```yaml
# build.yaml
build_from:
  amd64: your-registry.com/base-image:latest
```

### Multi-Repository Support

```bash
# Clone and setup multiple add-ons
git clone https://github.com/your-username/addon1
git clone https://github.com/your-username/addon2
# Run install script in each directory
```

### CI/CD Integration

The installation scripts automatically set up GitHub Actions workflows for:

- Multi-architecture builds
- Automated testing
- Release management
- Container registry publishing

---

## Support

For additional help:

- 📖 [Home Assistant Add-on Development Documentation](https://developers.home-assistant.io/docs/add-ons)
- 🦎 [Komodo Documentation](https://komo.do/docs)
- 💬 [Home Assistant Community Forum](https://community.home-assistant.io)
- 🐛 [GitHub Issues](https://github.com/nelsonni/komodo-periphery-ha-addon/issues)
