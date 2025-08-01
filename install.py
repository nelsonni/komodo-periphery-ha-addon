#!/usr/bin/env python3
"""
Komodo Periphery Home Assistant Add-on Installation Script
Cross-platform Python version supporting Linux, macOS, and Windows
Usage: python install.py [--dev|--production] [--help]
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Optional

# Configuration
ADDON_NAME = "komodo-periphery"
ADDON_SLUG = "komodo_periphery"
REPO_NAME = "komodo-periphery-addon"


class Colors:
    """ANSI color codes for terminal output"""

    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"
    WHITE = "\033[97m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"

    @classmethod
    def disable(cls):
        """Disable colors for Windows without ANSI support"""
        cls.RED = cls.GREEN = cls.YELLOW = cls.BLUE = ""
        cls.MAGENTA = cls.CYAN = cls.WHITE = cls.ENDC = cls.BOLD = ""

    @classmethod
    def enable(cls):
        """Re-enable colors (useful for testing)"""
        cls.RED = "\033[91m"
        cls.GREEN = "\033[92m"
        cls.YELLOW = "\033[93m"
        cls.BLUE = "\033[94m"
        cls.MAGENTA = "\033[95m"
        cls.CYAN = "\033[96m"
        cls.WHITE = "\033[97m"
        cls.ENDC = "\033[0m"
        cls.BOLD = "\033[1m"


class Installer:
    """
    Cross-platform installer for Komodo Periphery Home Assistant Add-on.

    Handles dependency installation, Home Assistant integration, and development
    environment setup across Linux, macOS, and Windows platforms.
    """

    def __init__(self):
        self.os_type = platform.system().lower()
        self.ha_config_dir: Optional[Path] = None
        self.ha_addons_dir: Optional[Path] = None

        # Disable colors on Windows unless in modern terminal
        if self.os_type == "windows" and not self._supports_ansi():
            Colors.disable()

    def _supports_ansi(self) -> bool:
        """Check if terminal supports ANSI escape sequences"""
        return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()

    def print_status(self, message: str):
        """Print status message in green"""
        print(f"{Colors.GREEN}[INFO]{Colors.ENDC} {message}")

    def print_warning(self, message: str):
        """Print warning message in yellow"""
        print(f"{Colors.YELLOW}[WARN]{Colors.ENDC} {message}")

    def print_error(self, message: str):
        """Print error message in red"""
        print(f"{Colors.RED}[ERROR]{Colors.ENDC} {message}")

    def print_header(self):
        """Print installation header"""
        print(f"\n{Colors.BLUE}{'=' * 46}")
        print("  Komodo Periphery HA Add-on Installer")
        print(f"{'=' * 46}{Colors.ENDC}\n")

    def command_exists(self, command: str) -> bool:
        """Check if a command exists in PATH"""
        return shutil.which(command) is not None

    def run_command(
        self, command: List[str], check: bool = True
    ) -> subprocess.CompletedProcess:
        """Run a shell command"""
        try:
            return subprocess.run(command, check=check, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            self.print_error(f"Command failed: {' '.join(command)}")
            self.print_error(f"Error: {e.stderr}")
            raise

    def detect_package_manager(self) -> Optional[str]:
        """Detect available package manager on Linux"""
        managers = ["apt-get", "yum", "dnf", "pacman", "zypper"]
        for manager in managers:
            if self.command_exists(manager):
                return manager
        return None

    def install_dependencies(self):
        """Install required dependencies based on OS"""
        self.print_status("Installing dependencies...")

        required_tools = ["git", "docker"]
        missing_tools = [
            tool for tool in required_tools if not self.command_exists(tool)
        ]

        if self.os_type == "linux":
            self._install_linux_dependencies(missing_tools)
        elif self.os_type == "darwin":
            self._install_macos_dependencies(missing_tools)
        elif self.os_type == "windows":
            self._check_windows_dependencies(missing_tools)
        else:
            self.print_error(f"Unsupported operating system: {self.os_type}")
            sys.exit(1)

    def _install_linux_dependencies(self, missing_tools: List[str]):
        """Install dependencies on Linux"""
        if not missing_tools:
            self.print_status("All required tools are already installed.")
            return

        pkg_manager = self.detect_package_manager()
        if not pkg_manager:
            self.print_error("No supported package manager found.")
            self.print_error("Please install git, docker, and docker-compose manually.")
            sys.exit(1)

        self.print_status(f"Installing dependencies via {pkg_manager}...")

        if pkg_manager == "apt-get":
            self.run_command(["sudo", "apt-get", "update"])
            self.run_command(
                ["sudo", "apt-get", "install", "-y"]
                + missing_tools
                + ["docker-compose", "jq"]
            )
        elif pkg_manager in ["yum", "dnf"]:
            self.run_command(["sudo", pkg_manager, "update", "-y"])
            self.run_command(
                ["sudo", pkg_manager, "install", "-y"]
                + missing_tools
                + ["docker-compose", "jq"]
            )
        elif pkg_manager == "pacman":
            self.run_command(
                ["sudo", "pacman", "-Syu", "--noconfirm"]
                + missing_tools
                + ["docker-compose", "jq"]
            )

        # Start Docker service and add user to docker group
        if "docker" in missing_tools:
            try:
                self.run_command(["sudo", "systemctl", "enable", "docker"])
                self.run_command(["sudo", "systemctl", "start", "docker"])
                self.run_command(
                    ["sudo", "usermod", "-aG", "docker", os.getenv("USER", "user")]
                )
                self.print_warning(
                    "You may need to log out and back in for Docker group changes to take effect."
                )
            except subprocess.CalledProcessError:
                self.print_warning(
                    "Could not configure Docker service. Please configure manually."
                )

    def _install_macos_dependencies(self, missing_tools: List[str]):
        """Install dependencies on macOS"""
        if not self.command_exists("brew"):
            self.print_error("Homebrew not found. Please install Homebrew first:")
            self.print_error("https://brew.sh/")
            sys.exit(1)

        if missing_tools:
            self.print_status("Installing dependencies via Homebrew...")
            self.run_command(["brew", "install"] + missing_tools + ["jq"])

        if not self.command_exists("docker"):
            self.print_warning(
                "Docker Desktop not found. Please install Docker Desktop for Mac:"
            )
            self.print_warning("https://docs.docker.com/desktop/install/mac-install/")

    def _check_windows_dependencies(self, missing_tools: List[str]):
        """Check dependencies on Windows"""
        if missing_tools:
            self.print_warning("Missing required tools on Windows:")
            for tool in missing_tools:
                self.print_warning(f"  - {tool}")

            self.print_warning("\nPlease install:")
            self.print_warning("- Git for Windows: https://git-scm.com/download/win")
            self.print_warning(
                "- Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
            )

            choice = input("Continue anyway? (y/N): ")
            if choice.lower() != "y":
                sys.exit(1)

    def find_ha_config(self):
        """Find Home Assistant configuration directory"""
        self.print_status("Looking for Home Assistant configuration directory...")

        # Common paths for different OS
        home = Path.home()

        if self.os_type == "windows":
            ha_paths = [
                home / ".homeassistant",
                home / "homeassistant",
                home / "Documents" / "HomeAssistant",
                home / "Development" / "homeassistant",
                Path("C:/homeassistant"),
                Path("C:/config"),
            ]
        else:
            ha_paths = [
                home / ".homeassistant",
                home / "homeassistant",
                Path("/usr/share/hassio/homeassistant"),
                Path("/config"),
                home / "Documents" / "HomeAssistant",
                home / "Development" / "homeassistant",
            ]

        # Check environment variable
        env_path = os.getenv("HA_CONFIG_PATH")
        if env_path:
            ha_paths.insert(0, Path(env_path))

        # Find existing config
        for path in ha_paths:
            if (path / "configuration.yaml").exists():
                self.ha_config_dir = path
                self.ha_addons_dir = path / "addons"
                self.print_status(
                    f"Found Home Assistant config at: {self.ha_config_dir}"
                )
                return

        # Ask user for path
        self.print_warning(
            "Home Assistant configuration directory not found automatically."
        )
        user_path = input(
            "Please enter the path to your Home Assistant config directory: "
        )

        user_path = Path(user_path)
        if (user_path / "configuration.yaml").exists():
            self.ha_config_dir = user_path
            self.ha_addons_dir = user_path / "addons"
            self.print_status(f"Using Home Assistant config at: {self.ha_config_dir}")
        else:
            self.print_error("Invalid Home Assistant configuration directory.")
            sys.exit(1)

    def setup_devcontainer(self):
        """Setup VS Code devcontainer"""
        self.print_status("Setting up VS Code devcontainer...")

        devcontainer_dir = Path(".devcontainer")
        devcontainer_dir.mkdir(exist_ok=True)

        devcontainer_config = {
            "name": "Home Assistant Add-on Development",
            "image": "ghcr.io/home-assistant/devcontainer:addons",
            "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
            "mounts": [
                "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
            ],
            "features": {
                "ghcr.io/devcontainers/features/docker-in-docker:2": {},
                "ghcr.io/devcontainers/features/git:1": {},
            },
            "customizations": {
                "vscode": {
                    "extensions": [
                        "ms-vscode.vscode-json",
                        "redhat.vscode-yaml",
                        "ms-vscode.vscode-docker",
                        "esbenp.prettier-vscode",
                        "bradlc.vscode-tailwindcss",
                    ],
                    "settings": {
                        "terminal.integrated.defaultProfile.linux": "bash",
                        "editor.formatOnSave": True,
                        "editor.codeActionsOnSave": {"source.organizeImports": True},
                    },
                }
            },
            "postCreateCommand": "chmod +x install.sh && ./install.sh --dev",
            "remoteUser": "vscode",
        }

        with open(devcontainer_dir / "devcontainer.json", "w", encoding="utf-8") as f:
            json.dump(devcontainer_config, f, indent=2)

        self.print_status("Devcontainer configuration created.")

    def setup_local_dev(self):
        """Setup local development environment"""
        self.print_status("Setting up local development environment...")

        # Create addons directory
        self.ha_addons_dir.mkdir(exist_ok=True)

        addon_target = self.ha_addons_dir / ADDON_SLUG

        # Backup existing installation
        if addon_target.exists():
            backup_name = f"{addon_target}.backup.{self._get_timestamp()}"
            self.print_warning(f"Addon directory exists, backing up to: {backup_name}")
            shutil.move(str(addon_target), backup_name)

        # Try to create symlink, fallback to copy
        try:
            addon_target.symlink_to(Path.cwd(), target_is_directory=True)
            self.print_status(f"Created symlink: {addon_target} -> {Path.cwd()}")
        except OSError:
            # Symlink failed (common on Windows), copy instead
            self.print_warning("Cannot create symlink, copying files instead...")
            shutil.copytree(
                ".",
                str(addon_target),
                ignore=shutil.ignore_patterns(
                    ".git", ".devcontainer", "*.py", "*.sh", "*.ps1", "DEVELOPMENT.md"
                ),
            )
            self.print_status(f"Copied addon files to: {addon_target}")

    def build_addon(self):
        """Build addon Docker image"""
        self.print_status("Building addon Docker image...")

        # Determine architecture
        machine = platform.machine().lower()
        arch_map = {
            "x86_64": "amd64",
            "amd64": "amd64",
            "aarch64": "aarch64",
            "arm64": "aarch64",
            "armv7l": "armv7",
        }

        arch = arch_map.get(machine, "amd64")
        image_name = f"ghcr.io/home-assistant/{ADDON_SLUG}-{arch}:latest"

        if not self.command_exists("docker"):
            self.print_error(
                "Docker not available. Please install Docker to build the addon."
            )
            sys.exit(1)

        try:
            self.print_status(f"Building Docker image: {image_name}")
            self.run_command(
                [
                    "docker",
                    "build",
                    "--build-arg",
                    f"BUILD_ARCH={arch}",
                    "-t",
                    image_name,
                    ".",
                ]
            )
            self.print_status("Build completed successfully!")
        except subprocess.CalledProcessError:
            self.print_error("Docker build failed.")
            sys.exit(1)

    def setup_production(self):
        """Setup production deployment files"""
        self.print_status("Setting up production deployment...")

        # Create build.yaml
        build_config = f"""build_from:
  aarch64: ghcr.io/home-assistant/alpine-base:3.21
  amd64: ghcr.io/home-assistant/alpine-base:3.21
  armhf: ghcr.io/home-assistant/alpine-base:3.21
  armv7: ghcr.io/home-assistant/alpine-base:3.21
  i386: ghcr.io/home-assistant/alpine-base:3.21
labels:
  org.opencontainers.image.title: "Komodo Periphery"
  org.opencontainers.image.description: "Komodo Periphery agent for Home Assistant OS monitoring"
  org.opencontainers.image.source: "https://github.com/your-username/{REPO_NAME}"
  org.opencontainers.image.licenses: "MIT"
args:
  KOMODO_VERSION: "latest"
codenotary: "your-email@example.com"
"""

        with open("build.yaml", "w", encoding="utf-8") as f:
            f.write(build_config)

        self.print_status("Production deployment files created.")

    def create_documentation(self):
        """Create development documentation"""
        self.print_status("Creating development documentation...")

        dev_doc = """# Komodo Periphery Add-on Development

## Development Setup

### Prerequisites
- Python 3.7+
- Docker and Docker Compose
- Git
- Visual Studio Code (recommended)

### Cross-Platform Installation
```bash
# Using Python (cross-platform)
python install.py --dev

# Using Bash (Linux/macOS)
./install.sh --dev

# Using PowerShell (Windows)
.\\install.ps1 -Dev
```

### Platform-Specific Notes

#### Linux
- Package manager detection (apt, yum, pacman)
- Automatic Docker service configuration
- User added to docker group

#### macOS
- Requires Homebrew
- Docker Desktop installation check
- Xcode Command Line Tools may be needed

#### Windows
- PowerShell 5.1+ required
- Docker Desktop for Windows
- WSL2 recommended for performance
- Git Bash alternative for shell scripts

### Development Workflow
1. Make changes to configuration or scripts
2. Test locally: `python install.py --dev`
3. Build and test: `docker build -t komodo-periphery .`
4. Submit pull request

### Architecture Support
- amd64 (x86_64)
- aarch64 (ARM64)
- armv7 (ARM 32-bit)
- armhf (ARM hard-float)
- i386 (x86 32-bit)

### Directory Structure
```
komodo_periphery/
├── config.yaml              # Add-on configuration
├── Dockerfile               # Container definition
├── README.md                # User documentation
├── icon.svg                 # Add-on icon (128x128)
├── rootfs/                  # Container filesystem
│   └── etc/services.d/
│       └── komodo-periphery/
│           ├── run          # S6 service script
│           └── finish       # S6 cleanup script
├── translations/            # UI translations
│   └── en.yaml
├── .devcontainer/           # VS Code devcontainer
├── install.py               # Python installer
├── install.sh               # Bash installer
└── install.ps1              # PowerShell installer
```
"""

        with open("DEVELOPMENT.md", "w", encoding="utf-8") as f:
            f.write(dev_doc)

        self.print_status("Development documentation created.")

    def _get_timestamp(self) -> str:
        """Get timestamp for backups"""
        import datetime  # pylint: disable=import-outside-toplevel

        return datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    def initialize_git(self):
        """Initialize Git repository if not exists"""
        if not Path(".git").exists():
            self.print_status("Initializing Git repository...")
            self.run_command(["git", "init"])

            gitignore = """# Build artifacts
build/
dist/
*.log

# Development files
.DS_Store
Thumbs.db
*.tmp
*.temp
__pycache__/
*.pyc

# VS Code
.vscode/settings.json
.vscode/launch.json

# Local configuration
local_config.yaml
secrets.yaml

# Backup files
*.backup.*
"""

            with open(".gitignore", "w", encoding="utf-8") as f:
                f.write(gitignore)

            self.run_command(["git", "add", "."])
            self.run_command(
                [
                    "git",
                    "commit",
                    "-m",
                    "Initial commit: Komodo Periphery Home Assistant Add-on",
                ]
            )
            self.print_status("Git repository initialized.")


def setup_development_environment(installer: Installer):
    """Set up the development environment."""
    installer.print_status("Setting up development environment...")
    installer.find_ha_config()
    installer.setup_devcontainer()
    installer.setup_local_dev()
    installer.build_addon()
    installer.create_documentation()
    installer.initialize_git()

    print(f"\n{Colors.GREEN}Development setup complete!{Colors.ENDC}\n")
    installer.print_status("Next steps:")
    print("1. Open this project in Visual Studio Code")
    print("2. Install the 'Dev Containers' extension")
    print("3. Use Ctrl+Shift+P and select 'Dev Containers: Reopen in Container'")
    print(
        "4. Find the add-on in Home Assistant Supervisor -> Add-on Store -> Local add-ons"
    )


def setup_production_environment(installer: Installer):
    """Set up the production environment."""
    installer.print_status("Setting up production deployment...")
    installer.setup_production()
    installer.create_documentation()
    installer.initialize_git()

    print(f"\n{Colors.GREEN}Production setup complete!{Colors.ENDC}\n")
    installer.print_status("Next steps:")
    print("1. Update repository URL in build.yaml")
    print("2. Create GitHub repository and push code")
    print("3. GitHub Actions will build multi-architecture images")
    print("4. Users can install from your repository")


def main():
    """Main entry point for the installation script."""
    parser = argparse.ArgumentParser(
        description="Komodo Periphery Home Assistant Add-on Installation Script"
    )
    parser.add_argument(
        "--dev", action="store_true", help="Set up development environment (default)"
    )
    parser.add_argument(
        "--production", action="store_true", help="Set up production deployment files"
    )

    args = parser.parse_args()

    # Default to dev mode if neither specified
    if not args.dev and not args.production:
        args.dev = True

    installer = Installer()
    installer.print_header()

    try:
        installer.install_dependencies()

        if args.dev:
            setup_development_environment(installer)
        elif args.production:
            setup_production_environment(installer)

        print(f"\n{Colors.GREEN}Installation completed successfully!{Colors.ENDC}")

    except KeyboardInterrupt:
        installer.print_warning("\nInstallation cancelled by user.")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        installer.print_error(f"Installation failed with command error: {e}")
        sys.exit(1)
    except (OSError, IOError) as e:
        installer.print_error(f"Installation failed with file system error: {e}")
        sys.exit(1)
    except Exception as e:  # pylint: disable=broad-exception-caught
        installer.print_error(f"Installation failed with unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
