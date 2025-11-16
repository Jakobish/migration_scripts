<#
    Interactive IIS Website Migration Tool
    ---------------------------------------
    Features:
    - Menu-driven UX
    - Select website to migrate
    - Enter destination server
    - Optional content copy (files)
    - Auto-binding IP update
    - Auto-generated msdeploy sync command
#>

Import-Module WebAdministration

function Show-Menu {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   IIS Web Migration Interactive Tool"
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1) Migrate a website to another server"
    Write-Host "2) Exit"
    Write-Host ""
}

function Get-YesNo($message, $default = $true) {
    $suffix = if ($default) { "[Y]/n" } else { "y/[N]" }
    while ($true) {
        $answer = Read-Host "$message $suffix"
        if ($answer -eq "" -and $default) { return $true }
        if ($answer -eq "" -and -not $default) { return $false }
        if ($answer.ToLower() -in @("y", "yes")) { return $true }
        if ($answer.ToLower() -in @("n", "no")) { return $false }
        Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Yellow
    }
}

function Select-Website {
    $sites = Get-ChildItem IIS:\Sites | Select-Object Name, ID, State, Bindings, PhysicalPath

    Clear-Host
    Write-Host "Available IIS Sites:" -ForegroundColor Cyan
    Write-Host "--------------------------------------"

    $index = 1
    foreach ($site in $sites) {
        Write-Host "$index) $($site.Name)"
        $index++
    }

    Write-Host ""
    $choice = Read-Host "Select a site number"

    if ($choice -lt 1 -or $choice -gt $sites.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        return $null
    }

    return $sites[$choice - 1]
}

function Start-IISMigration {
    $site = Select-Website
    if ($null -eq $site) { return }

    $siteName = $site.Name
    Write-Host ""
    Write-Host "Selected site: $siteName" -ForegroundColor Green
    Write-Host ""

    $destinationIPaddress = Read-Host "Enter destination server IP"
    if ([string]::IsNullOrWhiteSpace($destinationIPaddress)) {
        Write-Host "Destination cannot be empty." -ForegroundColor Red
        return
    }

    $copyFiles = Get-YesNo "Copy site physical files?" $true

    # Log file
    $timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
    $logFile = ".\migration-$siteName-$timestamp.log"

    # Base command
    $msdeploy = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"
    $cmd = @()
    $cmd += "`"$msdeploy`""
    $cmd += "-verb:sync"
    $cmd += "-source:appHostConfig=`"$siteName`""
    $cmd += "-dest:appHostConfig=`"$siteName`",computerName=`"$destinationIPaddress`""

    # Auto-binding replacement rule (virtualDirectory / bindings)
    $cmd += "-replace:objectName=binding,match=""\d{1,3}(\.\d{1,3}){3}"",replace=""$destinationIPaddress"""

    # Enable required links
    $cmd += "-enableLink:AppPoolExtension"
    $cmd += "-enableLink:CertificateExtension"

    if ($copyFiles) {
        $cmd += "-enableLink:ContentExtension"
    }
    else {
        $cmd += "-disableLink:ContentExtension"
    }

    #$cmd += "-retryAttempts:3"
    #$cmd += "-retryInterval:5000"

    $finalCommand = $cmd -join " "

    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "       Migration Command Preview"
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host $finalCommand -ForegroundColor Yellow
    Write-Host ""
    $run = Get-YesNo "Execute this command?"

    if (-not $run) {
        Write-Host "Migration aborted by user." -ForegroundColor Yellow
        return
    }

    Write-Host "Running migration..." -ForegroundColor Cyan

    try {
        & cmd.exe /c $finalCommand 2>&1 | Tee-Object -FilePath $logFile
        Write-Host "Migration completed. Log saved to $logFile" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        Add-Content $logFile "ERROR: $_"
    }
}

# ======== MAIN LOOP ========

while ($true) {
    Show-Menu
    $choice = Read-Host "Choose an option"

    switch ($choice) {
        "1" { Start-IISMigration }
        "2" { break }
        default { Write-Host "Invalid choice." -ForegroundColor Yellow }
    }

    Write-Host ""
    Write-Host "Press Enter to continue..."
    Read-Host
}