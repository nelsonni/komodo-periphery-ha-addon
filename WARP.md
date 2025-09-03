# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a **Home Assistant Add-on** for Komodo Periphery, a Rust-based system monitoring agent. The add-on packages the Komodo Periphery binary into a containerized Home Assistant add-on that provides system metrics monitoring and Docker container management.

**Key Technologies:**
- Home Assistant Add-on system (Alpine Linux base images)
- Docker multi-architecture builds (armhf, armv7, aarch64, amd64, i386)
- S6 overlay for service supervision
- Python for installation and development tooling
- Bash scripts for service management
- Komodo Periphery agent (external Rust binary)

## Development Commands

### Quick Setup
```bash
# Install development environment
make install

# Start development environment
make dev
# Or alternatively: make up

# View logs
make logs

# Stop development environment  
make down
```

### Building and Testing
```bash
# Build for default architecture (amd64)
make build

# Build for specific architecture
make build-arch ARCH=aarch64

# Build for all supported architectures
make build-all

# Run all tests
make test

# Run quick tests without Docker
make quick-test

# Test specific components
make test-build      # Test build process
make test-config     # Test configuration files
make test-install    # Test installation scripts
```

### Code Quality and Linting
```bash
# Run all linters
make lint

# Run specific linters
make lint-python     # Python code with ruff + pylint
make lint-docker     # Dockerfile with hadolint
make lint-yaml       # YAML files with yamllint
make lint-shell      # Shell scripts with shellcheck

# Format Python code
make format-python
```

### Security and Analysis
```bash
# Run security scans
make security

# Run Trivy vulnerability scan
make security-trivy

# Check Docker security
make security-docker
```

### Development Helpers
```bash
# Open shell in development container
make shell

# Check development environment status
make status

# Show build information
make info

# Check available tools
make check-tools

# Show debug information
make debug

# Clean up containers and images
make clean

# Deep cleanup including volumes
make clean-all
```

### Python Testing
```bash
# Run pytest tests
python -m pytest

# Run specific test types
python -m pytest -m unit           # Unit tests only
python -m pytest -m integration    # Integration tests only
python -m pytest -m "not slow"     # Skip slow tests

# Run with coverage
python -m pytest --cov=. --cov-report=html
```

### Alternative Installation Methods
```bash
# Python-based installer
python install.py --dev

# Shell-based installer (Linux/macOS)
./install.sh --dev

# Windows installers
install.bat        # Windows batch
install.ps1        # PowerShell
```

## Architecture and Structure

### Add-on Architecture
This follows the **Home Assistant Add-on pattern**:

1. **Multi-architecture Docker builds** using `build.yaml` configuration
2. **S6 overlay supervision** for service lifecycle management
3. **Bashio integration** for Home Assistant configuration parsing
4. **Service directory structure** (`rootfs/etc/services.d/`)
5. **Configuration schema validation** via `config.yaml`

### Key Components

**Configuration Files:**
- `config.yaml` - Home Assistant add-on configuration and schema
- `build.yaml` - Multi-architecture build configuration
- `docker-compose.dev.yaml` - Development environment setup
- `pyproject.toml` - Python tooling configuration (ruff, pylint, pytest)

**Service Management:**
- `rootfs/etc/services.d/komodo-periphery/run` - Main service startup script
- `rootfs/etc/services.d/komodo-periphery/finish` - Service cleanup script
- Uses S6 overlay for process supervision and automatic restarts

**Development Tools:**
- `Makefile` - Comprehensive build and development commands
- `install.py` - Cross-platform Python installer
- `tests/` - pytest-based test suite with Docker integration
- `.devcontainer/` - VS Code development container support

### Build System
- **Base Images**: `ghcr.io/home-assistant/alpine-base:3.21`
- **Supported Architectures**: armhf, armv7, aarch64, amd64, i386
- **Runtime**: Downloads Komodo Periphery binary from GitHub releases
- **Security**: Runs as non-root user (`komodo`) with minimal privileges

### Configuration Flow
1. Home Assistant passes configuration via environment variables
2. `run` script reads configuration using `bashio::config`
3. Generates TOML configuration file for Komodo Periphery
4. SSL certificates generated if SSL enabled
5. Service starts as non-root user with proper permissions

### Testing Strategy
- **Unit Tests**: Configuration parsing and validation
- **Integration Tests**: Docker container functionality
- **Build Tests**: Multi-architecture Docker builds
- **Security Tests**: Vulnerability scanning with Trivy
- **Lint Tests**: Code quality across Python, Shell, YAML, and Dockerfile

## Development Environment

### Docker Compose Services
- **komodo-periphery**: Main development service
- **komodo-core-mock**: Optional mock server for testing (profile: `mock`)
- **dev-tools**: Development utilities container (profile: `tools`)
- **ha-supervisor**: Home Assistant Supervisor simulator (profile: `supervisor`)

### Environment Variables
Development environment uses `.env` file (copied from `env.development`):
- `KOMODO_ADDRESS` - Komodo Core server URL
- `KOMODO_API_KEY` / `KOMODO_API_SECRET` - Authentication
- `LOG_LEVEL` - Logging level (trace, debug, info, warn, error)
- `STATS_POLLING_RATE` - System stats polling frequency
- `CONTAINER_STATS_POLLING_RATE` - Container stats polling frequency
- `SSL_ENABLED` - Enable HTTPS for Periphery API

### Code Quality Standards
This project follows **Home Assistant Core practices**:
- **Ruff** for Python formatting and linting (replaces black, isort, flake8)
- **Pylint** for additional static analysis
- **yamllint** for YAML validation
- **hadolint** for Dockerfile linting  
- **shellcheck** for shell script validation
- Line length: 88 characters (standard for Home Assistant)

### Multi-Architecture Support
All builds support 5 architectures through Docker buildx:
- `amd64` (x86_64)
- `aarch64` (ARM64)
- `armv7` (ARM v7)
- `armhf` (ARM hard-float)
- `i386` (32-bit x86)

Build arguments automatically map architectures and download appropriate Komodo Periphery binaries.

## Common Development Workflows

### Adding New Configuration Options
1. Update `config.yaml` schema and options
2. Modify `rootfs/etc/services.d/komodo-periphery/run` to handle new config
3. Update README.md configuration documentation
4. Add tests in `tests/test_addon_config.py`
5. Test with `make test-config`

### Updating Dependencies
1. Update package versions in `Dockerfile` (with fallback strategy)
2. Update Python dependencies in `pyproject.toml`
3. Run `make build` and `make test` to verify
4. Use `scripts/update-package-versions.sh` for systematic updates

### Testing Across Architectures
1. Use `make build-all` to build all architectures
2. Test critical architectures: `make build-arch ARCH=aarch64`
3. Use GitHub Actions for full multi-arch CI/CD
4. Test on actual target hardware when possible

### Debugging Container Issues
1. `make dev` to start development environment
2. `make shell` to access running container
3. `make logs` to view service output
4. Check container health: `docker compose -f docker-compose.dev.yaml ps`
5. Test SSL: `curl -f -k https://localhost:8120/health`

## Security Considerations

- **Non-root execution**: Service runs as `komodo` user (UID 1000)
- **Minimal privileges**: Only required capabilities (SYS_ADMIN for monitoring)
- **Docker socket access**: Read-only access for container monitoring
- **SSL/TLS**: Self-signed certificates generated automatically
- **Input validation**: Configuration schema enforced via bashio
- **Secrets handling**: API keys handled as password fields in schema
- **Regular updates**: Alpine base image updated regularly for security patches
