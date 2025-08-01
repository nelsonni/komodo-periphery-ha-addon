#!/bin/bash
# format-check.sh - Local formatting script that matches CI

set -e

echo "🔍 Checking code formatting with CI-compatible tools..."

# Pin the same versions as CI
REQUIRED_BLACK_VERSION="25.1.0"
REQUIRED_ISORT_VERSION="5.13.2"

# Function to check and install tool version
check_tool_version() {
    local tool=$1
    local required_version=$2
    local current_version
    
    if command -v "$tool" >/dev/null 2>&1; then
        current_version=$($tool --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ "$current_version" != "$required_version" ]; then
            echo "⚠️ $tool version mismatch. Required: $required_version, Found: $current_version"
            echo "Installing correct version..."
            pip install "$tool==$required_version"
        else
            echo "✅ $tool version $current_version matches required version"
        fi
    else
        echo "📦 Installing $tool $required_version..."
        pip install "$tool==$required_version"
    fi
}

# Check and install required versions
check_tool_version "black" "$REQUIRED_BLACK_VERSION"
check_tool_version "isort" "$REQUIRED_ISORT_VERSION"

echo ""
echo "🔧 Tool versions:"
black --version
isort --version-number
echo ""

# Format the code (same as CI but with fixes)
echo "🎨 Formatting install.py..."
black install.py
isort install.py

echo "🎨 Formatting test files..."
if [ -d "tests" ]; then
    black tests/
    isort tests/
fi

echo ""
echo "✅ Code formatting completed!"
echo ""
echo "💡 To check without modifying files (like CI does):"
echo "   black --check --diff install.py"
echo "   isort --check-only --diff install.py"