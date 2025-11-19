#!/bin/bash
# IIS Migration Scripts GUI Launcher for macOS
# Requires administrator privileges via sudo

echo "========================================="
echo "  IIS Migration Scripts - GUI Launcher"
echo "========================================="
echo ""
echo "Starting GUI with administrator privileges..."
echo "Note: You may be prompted for administrator access"
echo ""

# Check if PowerShell is available
if ! command -v pwsh &> /dev/null; then
    echo "Error: PowerShell (pwsh) is not available"
    echo "Please install PowerShell to run the GUI"
    echo ""
    echo "To install PowerShell on macOS:"
    echo "  - Via Homebrew: brew install --cask powershell"
    echo "  - Or download from: https://github.com/PowerShell/PowerShell/releases"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

# Check if the GUI script exists
if [ ! -f "gui-migrate.ps1" ]; then
    echo "Error: gui-migrate.ps1 not found in current directory"
    echo "Please run this script from the IIS migration scripts directory"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

# Launch PowerShell with sudo if needed
echo "Launching GUI..."
echo ""
sudo pwsh -ExecutionPolicy Bypass -File "./gui-migrate.ps1"

echo ""
echo "GUI closed."
echo ""
read -p "Press Enter to exit..."