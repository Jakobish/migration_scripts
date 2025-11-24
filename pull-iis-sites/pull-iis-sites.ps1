#Requires -Version 7.0

<#
.SYNOPSIS
    Pulls IIS site configurations from a remote server using MSDeploy in parallel.

.DESCRIPTION
    This script reads configuration from pull-iis-sites.config.json and uses MSDeploy 
    to pull IIS site configurations from a remote server in parallel.

.PARAMETER ConfigFile
    Path to the JSON configuration file.
    Default: .\pull-iis-sites.config.json

.EXAMPLE
    .\pull-iis-sites.ps1
    
    Uses default config file (.\pull-iis-sites.config.json)

.EXAMPLE
    .\pull-iis-sites.ps1 -ConfigFile .\my-config.json
    
    Uses a custom configuration file

.NOTES
    Requires PowerShell 7+
    Requires MSDeploy (Web Deploy)
    Configuration file must contain: Computer, Username, Password, DomainListFile
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ConfigFile = ".\pull-iis-sites.config.json"
)

#region Helper Functions

function Write-ColorOutput {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $color = switch ($Type) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'White' }
    }
    
    $prefix = switch ($Type) {
        'Success' { '[✓]' }
        'Warning' { '[!]' }
        'Error' { '[✗]' }
        default { '[i]' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

#endregion

try {
    # Header
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  IIS Sites Pull Tool" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Read configuration
    Write-ColorOutput "Reading configuration from: $ConfigFile" -Type Info
    if (!(Test-Path $ConfigFile)) {
        Write-ColorOutput "Configuration file not found: $ConfigFile" -Type Error
        Write-ColorOutput "Create a pull-iis-sites.config.json file with required settings" -Type Info
        exit 1
    }

    $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    
    # Validate required settings
    $requiredSettings = @('Computer', 'Username', 'Password', 'DomainListFile')
    foreach ($setting in $requiredSettings) {
        if (-not $config.$setting) {
            Write-ColorOutput "Missing required setting in config: $setting" -Type Error
            exit 1
        }
    }
    


    
    # Apply defaults
    $Computer = $config.Computer
    $Username = $config.Username
    $Password = $config.Password
    $DomainListFile = if ($config.DomainListFile) { $config.DomainListFile } else { ".\domains.txt" }
    $LogDir = if ($config.LogDir) { $config.LogDir } else { ".\logs" }
    $MaxParallel = if ($config.MaxParallel) { $config.MaxParallel } else { 8 }
    $MSDeployPath = if ($config.MSDeployPath) { $config.MSDeployPath } else { "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe" }
    $MaxWebsites = if ($config.MaxWebsites) { $config.MaxWebsites } else { 0 }
    $WhatIf = if ($config.WhatIf) { $config.WhatIf } else { $false }

    Write-ColorOutput "Target Server: $Computer" -Type Info
    Write-ColorOutput "Username: $Username" -Type Info
    Write-ColorOutput "Max Parallel: $MaxParallel" -Type Info
    if ($MaxWebsites -gt 0) {
        Write-ColorOutput "Max Websites: $MaxWebsites" -Type Info
    }

    # Validate MSDeploy
    if (!(Test-Path $MSDeployPath)) {
        Write-ColorOutput "MSDeploy not found at: $MSDeployPath" -Type Error
        exit 1
    }

    # Create log directory
    if (!(Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -ErrorAction Stop | Out-Null
        Write-ColorOutput "Created log directory: $LogDir" -Type Success
    }

    # Read domains
    if (!(Test-Path $DomainListFile)) {
        Write-ColorOutput "Domain list file not found: $DomainListFile" -Type Error
        exit 1
    }

    $Domains = Get-Content $DomainListFile -ErrorAction Stop | 
    Where-Object { $_.Trim() -ne "" -and !$_.TrimStart().StartsWith('#') } |
    ForEach-Object { $_.Trim() }
    
    if ($Domains.Count -eq 0) {
        Write-ColorOutput "No domains found in $DomainListFile" -Type Error
        exit 1
    }
    
    # Limit the number of websites if MaxWebsites is set
    if ($MaxWebsites -gt 0 -and $Domains.Count -gt $MaxWebsites) {
        $Domains = $Domains | Select-Object -First $MaxWebsites
        Write-ColorOutput "Limited to first $MaxWebsites domain(s) from $DomainListFile" -Type Warning
    }
    
    Write-ColorOutput "Processing $($Domains.Count) domain(s)" -Type Success
    
    if ($WhatIf) {
        Write-ColorOutput "Running in WHATIF mode - no actual changes will be made" -Type Warning
    }

    Write-Host "`nStarting parallel operations...`n" -ForegroundColor Cyan

    # Execute parallel processing
    $startTime = Get-Date
    $results = $Domains | ForEach-Object -Parallel {
        param($Computer, $Username, $Password, $MSDeployPath, $LogDir, $WhatIf)
        
        $domain = $PSItem
        $LogFile = Join-Path $LogDir "$domain.log"

        # Build MSDeploy command
        $whatIfParam = if ($WhatIf) { "-whatif" } else { "" }

        $msdeployArgs = @(
            "-verb:sync"
            "-source:appHostConfig=`"$domain`",computerName=`"$Computer`",userName=`"$Username`",password=`"$Password`",authType=`"NTLM`""
            "-dest:appHostConfig=`"$domain`""
            "-allowUntrusted"
            "-enableLink:AppPoolExtension"
        )
        if ($whatIfParam) { $msdeployArgs += $whatIfParam }

        # Log header
        $sanitizedArgs = $msdeployArgs -replace "password=`"[^`"]+`"", "password=`"***`""
        $logHeader = @"
========================================
Domain: $domain
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Command: \"$MSDeployPath\" $($sanitizedArgs -join ' ')
========================================

"@
        $logHeader | Out-File -FilePath $LogFile -Encoding UTF8

        # Execute MSDeploy
        $success = $false
        try {
            $timestamp = Get-Date -Format "HH:mm:ss"
            "[$timestamp] Executing..." | Out-File -FilePath $LogFile -Append -Encoding UTF8

            $output = & $MSDeployPath $msdeployArgs 2>&1
            $output | Out-File -FilePath $LogFile -Append -Encoding UTF8

            if ($LASTEXITCODE -eq 0) {
                "[$timestamp] Exit Code: 0 (Success)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                $success = $true
            }
            else {
                "[$timestamp] Exit Code: $LASTEXITCODE (Failed)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            "[$timestamp] Error: $errorMsg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        }

        # Output progress
        if ($success) {
            Write-Host "[✓] $domain - Success" -ForegroundColor Green
            return @{ Domain = $domain; Success = $true; Message = "Completed successfully" }
        }
        else {
            Write-Host "[✗] $domain - Failed" -ForegroundColor Red
            return @{ Domain = $domain; Success = $false; Message = "Failed. See log: $LogFile" }
        }
    } -ThrottleLimit $MaxParallel

    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Summary
    $successCount = ($results | Where-Object { $_.Success }).Count
    $failureCount = ($results | Where-Object { -not $_.Success }).Count

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Execution Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-ColorOutput "Total domains processed: $($Domains.Count)" -Type Info
    Write-ColorOutput "Successful: $successCount" -Type Success
    if ($failureCount -gt 0) {
        Write-ColorOutput "Failed: $failureCount" -Type Error
        Write-Host "`nFailed domains:" -ForegroundColor Yellow
        $results | Where-Object { -not $_.Success } | ForEach-Object {
            Write-Host "  - $($_.Domain)" -ForegroundColor Yellow
        }
    }
    else {
        Write-ColorOutput "Failed: $failureCount" -Type Success
    }
    Write-ColorOutput "Duration: $($duration.ToString('mm\:ss'))" -Type Info
    Write-ColorOutput "Logs saved to: $LogDir" -Type Info
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Exit with appropriate code
    if ($failureCount -gt 0) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-ColorOutput "Fatal error: $_" -Type Error
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" -Type Error
    exit 1
}