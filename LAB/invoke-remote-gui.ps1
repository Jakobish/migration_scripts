#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Remote GUI Launcher - Execute IIS Migration GUI on remote servers
.DESCRIPTION
    This script allows you to remotely execute the IIS Migration GUI on target servers
    Similar to 'npx' functionality but for PowerShell and IIS migration scripts
    
.PARAMETER ComputerName
    Remote computer name or IP address
    
.PARAMETER Username
    Username for remote connection (optional if using current credentials)
    
.PARAMETER Method
    Connection method: WinRM, RDP, or Local
    
.PARAMETER Wait
    Wait for the remote process to complete
    
.EXAMPLE
    .\invoke-remote-gui.ps1 -ComputerName "192.168.1.100" -Method WinRM
    
.EXAMPLE
    .\invoke-remote-gui.ps1 -ComputerName "SERVER01" -Username "admin" -Method WinRM -Wait
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("WinRM", "RDP", "Local")]
    [string]$Method = "WinRM",
    
    [Parameter(Mandatory=$false)]
    [switch]$Wait,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Function to display help
function Show-Help {
    Write-Host @"
IIS Migration Scripts - Remote GUI Launcher
==========================================

USAGE:
    invoke-remote-gui.ps1 -ComputerName <server> [options]

PARAMETERS:
    -ComputerName    Target server name or IP address (REQUIRED)
    -Username        Username for remote connection (optional)
    -Method          Connection method: WinRM, RDP, Local (default: WinRM)
    -Wait            Wait for remote process to complete
    -WhatIf          Show what would be executed without running

EXAMPLES:
    # Basic remote execution
    .\invoke-remote-gui.ps1 -ComputerName "192.168.1.100"
    
    # With credentials
    .\invoke-remote-gui.ps1 -ComputerName "SERVER01" -Username "admin"
    
    # Using RDP method
    .\invoke-remote-gui.ps1 -ComputerName "SERVER02" -Method RDP
    
    # Wait for completion
    .\invoke-remote-gui.ps1 -ComputerName "SERVER03" -Wait
    
    # What-if mode (show commands without executing)
    .\invoke-remote-gui.ps1 -ComputerName "SERVER04" -WhatIf

REQUIREMENTS:
    - Administrator privileges on both local and remote machines
    - PowerShell remoting enabled (for WinRM method)
    - Microsoft Web Deploy V3 installed on remote server
    - IIS management tools installed on remote server

"@
}

# Check if help requested
if ($ComputerName -eq "help" -or $ComputerName -eq "-h" -or $ComputerName -eq "--help") {
    Show-Help
    exit 0
}

# Function to test WinRM connectivity
function Test-WinRMConnection {
    param([string]$ComputerName)
    
    Write-Host "Testing WinRM connectivity to $ComputerName..." -ForegroundColor Yellow
    
    try {
        $result = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
        Write-Host "✓ WinRM connection successful" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ WinRM connection failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Make sure PowerShell remoting is enabled on $ComputerName" -ForegroundColor Yellow
        return $false
    }
}

# Function to execute command remotely via WinRM
function Invoke-WinRMExecution {
    param(
        [string]$ComputerName,
        [string]$Username,
        [bool]$Wait,
        [bool]$WhatIf
    )
    
    $remoteScript = @'
# Remote GUI execution script
# Check for IIS and Web Deploy prerequisites
if (-not (Get-Module -ListAvailable -Name WebAdministration)) {
    Write-Error "WebAdministration module not found. Install IIS management tools."
    exit 1
}

$msDeployPath = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"
if (-not (Test-Path $msDeployPath)) {
    Write-Error "Microsoft Web Deploy V3 not found at $msDeployPath"
    exit 1
}

# Check if we're administrator
if (-not (Test-IsAdministrator)) {
    Write-Error "This script requires administrator privileges"
    exit 1
}

Write-Host "Starting IIS Migration GUI on $env:COMPUTERNAME..." -ForegroundColor Green

# Execute the GUI
try {
    $scriptPath = Join-Path $PSScriptRoot "gui-migrate.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Error "gui-migrate.ps1 not found in current directory"
        exit 1
    }
    
    & powershell -ExecutionPolicy Bypass -File $scriptPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "GUI completed successfully" -ForegroundColor Green
    } else {
        Write-Host "GUI exited with code: $LASTEXITCODE" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Failed to execute GUI: $($_.Exception.Message)"
    exit 1
}
'@
    
    $scriptBlock = [ScriptBlock]::Create($remoteScript)
    
    $invokeParams = @{
        ComputerName = $ComputerName
        ScriptBlock = $scriptBlock
    }
    
    if ($Username) {
        $credential = Get-Credential -Message "Enter credentials for $ComputerName" -UserName $Username
        $invokeParams.Credential = $credential
    }
    
    if ($WhatIf) {
        Write-Host "What-if: Would execute the following command remotely:" -ForegroundColor Cyan
        Write-Host "PowerShell -Command `"& { $remoteScript }`"" -ForegroundColor White
        return
    }
    
    Write-Host "Executing GUI remotely on $ComputerName..." -ForegroundColor Yellow
    
    try {
        if ($Wait) {
            Invoke-Command @invokeParams
        } else {
            Invoke-Command @invokeParams -AsJob | Out-Null
            Write-Host "GUI started as background job. Use Get-Job to monitor progress." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Remote execution failed: $($_.Exception.Message)"
    }
}

# Function to generate RDP connection
function New-RDPConnection {
    param([string]$ComputerName, [string]$Username)
    
    if ($WhatIf) {
        Write-Host "What-if: Would create RDP connection to $ComputerName" -ForegroundColor Cyan
        if ($Username) {
            Write-Host "  Command: mstsc /v:$ComputerName /u:$Username" -ForegroundColor White
        } else {
            Write-Host "  Command: mstsc /v:$ComputerName" -ForegroundColor White
        }
        return
    }
    
    $rdpParams = "/v:$ComputerName"
    if ($Username) {
        $rdpParams += " /u:$Username"
    }
    
    Write-Host "Opening RDP connection to $ComputerName..." -ForegroundColor Yellow
    Write-Host "Note: You'll need to manually run the GUI after connecting" -ForegroundColor Cyan
    Start-Process "mstsc" -ArgumentList $rdpParams
}

# Function to execute locally
function Invoke-LocalExecution {
    param([bool]$WhatIf)
    
    if ($WhatIf) {
        Write-Host "What-if: Would execute GUI locally" -ForegroundColor Cyan
        Write-Host "  Command: PowerShell -ExecutionPolicy Bypass -File .\gui-migrate.ps1" -ForegroundColor White
        return
    }
    
    Write-Host "Starting GUI locally..." -ForegroundColor Green
    
    try {
        & powershell -ExecutionPolicy Bypass -File ".\gui-migrate.ps1"
    }
    catch {
        Write-Error "Failed to execute GUI locally: $($_.Exception.Message)"
    }
}

# Main execution logic
Write-Host "IIS Migration Scripts - Remote GUI Launcher" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq "localhost" -or $ComputerName -eq "127.0.0.1") {
    Write-Host "Detected local execution" -ForegroundColor Yellow
    Invoke-LocalExecution -WhatIf $WhatIf
}
else {
    Write-Host "Target: $ComputerName" -ForegroundColor White
    Write-Host "Method: $Method" -ForegroundColor White
    if ($Username) {
        Write-Host "Username: $Username" -ForegroundColor White
    }
    Write-Host ""
    
    switch ($Method) {
        "WinRM" {
            if (Test-WinRMConnection -ComputerName $ComputerName) {
                Invoke-WinRMExecution -ComputerName $ComputerName -Username $Username -Wait $Wait.IsPresent -WhatIf $WhatIf
            }
        }
        "RDP" {
            New-RDPConnection -ComputerName $ComputerName -Username $Username
        }
        "Local" {
            Write-Host "Local method specified, but target is remote. Switching to WinRM." -ForegroundColor Yellow
            if (Test-WinRMConnection -ComputerName $ComputerName) {
                Invoke-WinRMExecution -ComputerName $ComputerName -Username $Username -Wait $Wait.IsPresent -WhatIf $WhatIf
            }
        }
    }
}

if (-not $WhatIf) {
    Write-Host ""
    Write-Host "For more information, run: .\invoke-remote-gui.ps1 -help" -ForegroundColor Cyan
}