# Komodo Periphery Home Assistant Add-on Installation Script (PowerShell)
# Usage: .\install.ps1 [-Dev] [-Production]

param(
    [switch]$Dev,
    [switch]$Production,
    [switch]$Help
)

# Configuration
$AddonName = "komodo-periphery"
$AddonSlug = "komodo_periphery"
$RepoName = "komodo-periphery-addon"
$HAAddonsDir = ""
$HAConfigDir = ""

# Colors for output
$Host.UI.RawUI.WindowTitle = "Komodo Periphery HA Add-on Installer"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Status {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARN] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Write-Header {
    Write-Host ""
    Write-ColorOutput "==============================================" "Blue"
    Write-ColorOutput "  Komodo Periphery HA Add-on Installer" "Blue"
    Write-ColorOutput "==============================================" "Blue"
    Write-Host ""
}

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Install-Dependencies {
    Write-Status "Checking and installing dependencies..."
    
    # Check for required tools
    $missingTools = @()
    
    if (-not (Test-CommandExists "git")) {
        $missingTools += "Git for Windows"
    }
    
    if (-not (Test-CommandExists "docker")) {
        $missingTools += "Docker Desktop"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Warning "Missing required tools:"
        foreach ($tool in $missingTools) {
            Write-Host "  - $tool" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-ColorOutput "Please install the missing tools:" "Cyan"
        Write-Host "1. Git for Windows: https://git-scm.com/download/win"
        Write-Host "2. Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
        Write-Host "3. Restart PowerShell after installation"
        
        $choice = Read-Host "Continue anyway? (y/N)"
        if ($choice -ne "y" -and $choice -ne "Y") {
            exit 1
        }
    }
    
    # Check for optional tools
    if (-not (Test-CommandExists "code")) {
        Write-Warning "Visual Studio Code not found. Install for better development experience:"
        Write-Host "https://code.visualstudio.com/download"
    }
    
    Write-Status "Dependencies check completed."
}

function Find-HAConfig {
    Write-Status "Looking for Home Assistant configuration directory..."
    
    # Common paths for Windows HA installations
    $haPaths = @(
        "$env:USERPROFILE\.homeassistant",
        "$env:USERPROFILE\homeassistant",
        "$env:USERPROFILE\Documents\HomeAssistant",
        "$env:USERPROFILE\Development\homeassistant",
        "C:\homeassistant",
        "C:\config"
    )
    
    # Check if user provided custom path via environment variable
    if ($env:HA_CONFIG_PATH) {
        $haPaths = @($env:HA_CONFIG_PATH) + $haPaths
    }
    
    foreach ($path in $haPaths) {
        if (Test-Path "$path\configuration.yaml") {
            $script:HAConfigDir = $path
            $script:HAAddonsDir = "$path\addons"
            Write-Status "Found Home Assistant config at: $HAConfigDir"
            return
        }
    }
    
    # If not found, ask user
    Write-Warning "Home Assistant configuration directory not found automatically."
    $userPath = Read-Host "Please enter the path to your Home Assistant config directory"
    
    if (Test-Path "$userPath\configuration.yaml") {
        $script:HAConfigDir = $userPath
        $script:HAAddonsDir = "$userPath\addons"
        Write-Status "Using Home Assistant config at: $HAConfigDir"
    } else {
        Write-Error "Invalid Home Assistant configuration directory."
        exit 1
    }
}

function Setup-DevContainer {
    Write-Status "Setting up VS Code devcontainer for Home Assistant add-on development..."
    
    $devcontainerDir = ".devcontainer"
    if (-not (Test-Path $devcontainerDir)) {
        New-Item -ItemType Directory -Path $devcontainerDir | Out-Null
    }
    
    $devcontainerConfig = @"
{
  "name": "Home Assistant Add-on Development",
  "image": "ghcr.io/home-assistant/devcontainer:addons",
  "workspaceFolder": "/workspaces/`${localWorkspaceFolderBasename}",
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
  "postCreateCommand": "chmod +x install.sh && ./install.sh --dev",
  "remoteUser": "vscode"
}
"@
    
    Set-Content -Path "$devcontainerDir\devcontainer.json" -Value $devcontainerConfig -Encoding UTF8
    Write-Status "Devcontainer configuration created."
}

function Setup-LocalDev {
    Write-Status "Setting up local development environment..."
    
    # Create addons directory if it doesn't exist
    if (-not (Test-Path $HAAddonsDir)) {
        New-Item -ItemType Directory -Path $HAAddonsDir -Force | Out-Null
    }
    
    $addonTarget = "$HAAddonsDir\$AddonSlug"
    
    # Remove existing installation
    if (Test-Path $addonTarget) {
        Write-Warning "Addon directory already exists, backing up..."
        $backupName = "${addonTarget}.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Move-Item $addonTarget $backupName
        Write-Status "Backup created: $backupName"
    }
    
    # Copy files (Windows doesn't support symlinks without admin rights by default)
    Write-Status "Copying addon files to: $addonTarget"
    Copy-Item -Path . -Destination $addonTarget -Recurse -Force
    
    # Remove development files from the copy
    $devFiles = @(".git", ".devcontainer", "install.ps1", "install.sh", "DEVELOPMENT.md")
    foreach ($file in $devFiles) {
        $filePath = "$addonTarget\$file"
        if (Test-Path $filePath) {
            Remove-Item $filePath -Recurse -Force
        }
    }
    
    Write-Status "Local development environment set up successfully."
}

function Build-Addon {
    Write-Status "Building addon Docker image..."
    
    # Determine architecture
    $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { "amd64" }
        "ARM64" { "aarch64" }
        default { "amd64" }
    }
    
    $imageName = "ghcr.io/home-assistant/$AddonSlug-${arch}:latest"
    
    if (Test-CommandExists "docker") {
        Write-Status "Building Docker image: $imageName"
        
        try {
            docker build --build-arg BUILD_ARCH=$arch -t $imageName .
            Write-Status "Build completed successfully!"
        } catch {
            Write-Error "Docker build failed: $_"
            exit 1
        }
    } else {
        Write-Error "Docker not available. Please install Docker Desktop to build the addon."
        exit 1
    }
}

function Setup-Production {
    Write-Status "Setting up production deployment..."
    
    # Create build configuration
    $buildConfig = @"
build_from:
  aarch64: ghcr.io/home-assistant/alpine-base:3.21
  amd64: ghcr.io/home-assistant/alpine-base:3.21
  armhf: ghcr.io/home-assistant/alpine-base:3.21
  armv7: ghcr.io/home-assistant/alpine-base:3.21
  i386: ghcr.io/home-assistant/alpine-base:3.21
labels:
  org.opencontainers.image.title: "Komodo Periphery"
  org.opencontainers.image.description: "Komodo Periphery agent for Home Assistant OS monitoring"
  org.opencontainers.image.source: "https://github.com/your-username/$RepoName"
  org.opencontainers.image.licenses: "MIT"
args:
  KOMODO_VERSION: "latest"
codenotary: "your-email@example.com"
"@
    
    Set-Content -Path "build.yaml" -Value $buildConfig -Encoding UTF8
    
    # Create GitHub Actions workflow
    if (-not (Test-Path ".github\workflows")) {
        New-Item -ItemType Directory -Path ".github\workflows" -Force | Out-Null
    }
    
    $workflowContent = Get-Content "install.sh" | Select-String -Pattern "cat > `".github/workflows/builder.yaml`"" -A 100 | Select-Object -Skip 1 | Where-Object { $_ -notmatch "^EOF$" }
    # Note: This is a simplified approach. The full workflow content would be extracted from the bash script
    
    Write-Status "Production deployment files created."
    Write-Status "Please manually copy the GitHub Actions workflow from the bash script if needed."
}

function Create-Documentation {
    Write-Status "Creating development documentation..."
    
    $devDoc = @"
# Komodo Periphery Add-on Development (Windows)

## Development Setup

### Prerequisites
- Docker Desktop for Windows
- Git for Windows
- Visual Studio Code (recommended)
- PowerShell 5.1 or later

### Local Development
1. Clone this repository
2. Run ``.\install.ps1 -Dev`` to set up the development environment
3. Open in VS Code and use the devcontainer for consistent development environment

### Windows-Specific Notes
- Use PowerShell or Git Bash for command line operations
- Docker Desktop must be running for container builds
- WSL2 is recommended for better Docker performance

### Testing
- Use the Home Assistant Supervisor for local testing
- Build locally with: ``docker build -t komodo-periphery .``
- Test configuration changes in the add-on UI

### Troubleshooting
- Ensure Docker Desktop is running and WSL2 integration is enabled
- If symlinks fail, the script will copy files instead
- Use ``docker system prune`` to clean up build cache if needed
- Check Windows Defender exclusions for Docker and WSL directories

### Directory Structure
``````
komodo_periphery/
├── config.yaml              # Add-on configuration
├── Dockerfile               # Container definition
├── README.md                # User documentation
├── DEVELOPMENT.md           # Development guide
├── icon.svg                 # Add-on icon
├── rootfs/                  # Container filesystem
├── translations/            # UI translations
├── .devcontainer/           # VS Code devcontainer
└── .github/workflows/       # CI/CD
``````
"@
    
    Set-Content -Path "DEVELOPMENT.md" -Value $devDoc -Encoding UTF8
    Write-Status "Development documentation created."
}

function Show-Help {
    Write-Host ""
    Write-ColorOutput "Komodo Periphery Home Assistant Add-on Installation Script" "Cyan"
    Write-Host ""
    Write-Host "USAGE:"
    Write-Host "    .\install.ps1 [-Dev] [-Production] [-Help]"
    Write-Host ""
    Write-Host "OPTIONS:"
    Write-Host "    -Dev         Set up development environment (default)"
    Write-Host "    -Production  Set up production deployment files"
    Write-Host "    -Help        Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "    .\install.ps1 -Dev"
    Write-Host "    .\install.ps1 -Production"
    Write-Host ""
    Write-Host "ENVIRONMENT VARIABLES:"
    Write-Host "    HA_CONFIG_PATH   Custom path to Home Assistant configuration"
    Write-Host ""
}

function Test-Prerequisites {
    Write-Status "Checking system prerequisites..."
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1 or later is required. Current version: $psVersion"
        exit 1
    }
    
    # Check if running as admin (for symlink creation)
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Warning "Not running as Administrator. Symlink creation may fail, will use file copying instead."
    }
    
    # Check Windows version for WSL2 support
    $winVersion = [System.Environment]::OSVersion.Version
    if ($winVersion.Major -eq 10 -and $winVersion.Build -lt 19041) {
        Write-Warning "Windows 10 build 19041 or later recommended for best Docker Desktop performance."
    }
    
    Write-Status "Prerequisites check completed."
}

function Initialize-GitRepository {
    Write-Status "Initializing Git repository..."
    
    if (-not (Test-Path ".git")) {
        git init
        
        # Create .gitignore
        $gitignore = @"
# Build artifacts
build/
dist/
*.log

# Development files
.DS_Store
Thumbs.db
*.tmp
*.temp

# VS Code
.vscode/settings.json
.vscode/launch.json

# Local configuration
local_config.yaml
secrets.yaml

# Backup files
*.backup.*
"@
        Set-Content -Path ".gitignore" -Value $gitignore -Encoding UTF8
        
        git add .
        git commit -m "Initial commit: Komodo Periphery Home Assistant Add-on"
        
        Write-Status "Git repository initialized."
    } else {
        Write-Status "Git repository already exists."
    }
}

function Main {
    Write-Header
    
    # Show help if requested
    if ($Help) {
        Show-Help
        return
    }
    
    # Default to dev mode if neither specified
    if (-not $Dev -and -not $Production) {
        $Dev = $true
    }
    
    try {
        Test-Prerequisites
        Install-Dependencies
        
        if ($Dev) {
            Write-Status "Setting up development environment..."
            Find-HAConfig
            Setup-DevContainer
            Setup-LocalDev
            Build-Addon
            Create-Documentation
            Initialize-GitRepository
            
            Write-Host ""
            Write-ColorOutput "Development setup complete!" "Green"
            Write-Host ""
            Write-Status "Next steps:"
            Write-Host "1. Open this project in Visual Studio Code"
            Write-Host "2. Install the 'Dev Containers' extension if not already installed"
            Write-Host "3. Use Ctrl+Shift+P and select 'Dev Containers: Reopen in Container'"
            Write-Host "4. Find the add-on in Home Assistant: Supervisor -> Add-on Store -> Local add-ons"
            Write-Host "5. Install and configure the Komodo Periphery add-on"
            
        } elseif ($Production) {
            Write-Status "Setting up production deployment..."
            Setup-Production
            Create-Documentation
            Initialize-GitRepository
            
            Write-Host ""
            Write-ColorOutput "Production setup complete!" "Green"
            Write-Host ""
            Write-Status "Next steps:"
            Write-Host "1. Update the repository URL in build.yaml"
            Write-Host "2. Update your email in build.yaml for code signing"
            Write-Host "3. Create a GitHub repository and push this code"
            Write-Host "4. The GitHub Actions workflow will build multi-architecture images"
            Write-Host "5. Users can install from your repository"
        }
        
        Write-Host ""
        Write-ColorOutput "Installation completed successfully!" "Green"
        
    } catch {
        Write-Error "Installation failed: $_"
        Write-Host "Error details: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main