#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Configure WinRM TrustedHosts for PowerShell remoting to non-domain machines.

.DESCRIPTION
    This script helps configure the TrustedHosts setting required for PowerShell remoting
    to machines that are not in your domain or when not using Kerberos authentication.

.PARAMETER ComputerName
    The computer name or IP address to add to TrustedHosts.
    Use "*" to trust all computers (less secure).

.PARAMETER Append
    If specified, appends to existing TrustedHosts instead of replacing them.

.EXAMPLE
    .\Configure-TrustedHosts.ps1 -ComputerName "62.219.17.251"
    Adds the specified IP to TrustedHosts (replaces existing)

.EXAMPLE
    .\Configure-TrustedHosts.ps1 -ComputerName "62.219.17.251" -Append
    Adds the specified IP to TrustedHosts (appends to existing)

.EXAMPLE
    .\Configure-TrustedHosts.ps1 -ComputerName "*"
    Trusts all computers (use with caution)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ComputerName,
    
    [switch]$Append
)

try {
    # Check if running as administrator
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Error "This script must be run as Administrator."
        exit 1
    }

    # Get current TrustedHosts
    $currentTrustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    
    Write-Host "Current TrustedHosts: " -NoNewline
    if ($currentTrustedHosts) {
        Write-Host $currentTrustedHosts -ForegroundColor Cyan
    }
    else {
        Write-Host "(empty)" -ForegroundColor Yellow
    }

    # Determine new value
    $newValue = $ComputerName
    if ($Append -and $currentTrustedHosts) {
        $existingHosts = $currentTrustedHosts -split ',' | ForEach-Object { $_.Trim() }
        if ($existingHosts -notcontains $ComputerName) {
            $newValue = "$currentTrustedHosts,$ComputerName"
        }
        else {
            Write-Host "`n'$ComputerName' is already in TrustedHosts." -ForegroundColor Green
            exit 0
        }
    }

    # Set TrustedHosts
    Write-Host "`nSetting TrustedHosts to: " -NoNewline
    Write-Host $newValue -ForegroundColor Green
    
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $newValue -Force
    
    # Verify
    $verifyValue = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    Write-Host "`nTrustedHosts updated successfully!" -ForegroundColor Green
    Write-Host "New value: " -NoNewline
    Write-Host $verifyValue -ForegroundColor Cyan
    
    Write-Host "`nYou can now use PowerShell remoting to connect to: $ComputerName" -ForegroundColor Green
}
catch {
    Write-Error "Failed to configure TrustedHosts: $_"
    exit 1
}
