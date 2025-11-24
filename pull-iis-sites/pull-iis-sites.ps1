#Requires -Version 7.0

<#
.SYNOPSIS
    Pulls IIS site configurations from a remote server using MSDeploy in parallel.

.DESCRIPTION
    This script reads a list of domain/site names from a file and uses MSDeploy to pull
    IIS site configurations from a remote server. It supports parallel execution,
    separate console windows for detailed monitoring, and automatic retries.

.PARAMETER DomainListFile
    Path to the text file containing the list of domain/site names to pull.
    Default: .\domains.txt

.PARAMETER Computer
    The remote computer/server name or IP address where IIS sites are hosted.
    This parameter is mandatory.

.PARAMETER Credential
    PSCredential object containing username and password for remote authentication.
    If not provided, you will be prompted to enter credentials.

.PARAMETER LogDir
    Directory where log files will be stored. Created automatically if it doesn't exist.
    Default: .\logs

.PARAMETER MaxParallel
    Maximum number of parallel MSDeploy operations to run simultaneously.
    Valid range: 1-20
    Default: 8

.PARAMETER MSDeployPath
    Full path to the msdeploy.exe executable.
    Default: C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe

.PARAMETER EnableWhatIf
    When specified, runs MSDeploy in -whatif mode to preview changes without actually pulling sites.

.PARAMETER NewWindow
    If specified, opens a new PowerShell window for each domain execution to visualize progress.

.PARAMETER WorkerMode
    (Internal) Used by the script when spawning worker processes.

.PARAMETER WorkerDomain
    (Internal) The domain to process in Worker Mode.

.PARAMETER CredentialPath
    (Internal) Path to the exported credential file for Worker Mode.

.EXAMPLE
    .\pull-iis-sites.ps1 -Computer "10.0.0.50"
    
    Reads domains from .\domains.txt and pulls sites from 10.0.0.50 using default settings.

.EXAMPLE
    .\pull-iis-sites.ps1 -Computer "10.0.0.50" -NewWindow
    
    Opens a separate window for each domain to show real-time MSDeploy output.

.NOTES
    Requires PowerShell 7+
    Requires MSDeploy (Web Deploy)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$DomainListFile = ".\domains.txt",

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Computer,

    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ 
            if (!(Test-Path $_)) {
                $true  # Allow non-existent paths (will be created)
            }
            else {
                Test-Path $_ -PathType Container  # If exists, must be a directory
            }
        })]
    [string]$LogDir = ".\logs",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 20)]
    [int]$MaxParallel = 8,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$MSDeployPath = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe",

    [Parameter(Mandatory = $false)]
    [switch]$EnableWhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$NewWindow,

    # Internal parameters for Worker Mode
    [Parameter(Mandatory = $false, DontShow)]
    [switch]$WorkerMode,

    [Parameter(Mandatory = $false, DontShow)]
    [string]$WorkerDomain,

    [Parameter(Mandatory = $false, DontShow)]
    [string]$CredentialPath
)

#region Shared Functions

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

function Process-DomainItem {
    param(
        [string]$Domain,
        [string]$Computer,
        [string]$Username,
        [string]$Password,
        [string]$LogDir,
        [string]$MSDeployPath,
        [bool]$WhatIf
    )

    $LogFile = Join-Path $LogDir "$Domain.log"
    $MaxRetries = 3
    $RetryDelaySeconds = 5
    
    # Build MSDeploy command
    $whatIfParam = if ($WhatIf) { "-whatif" } else { "" }
    
    $msdeployArgs = @(
        "-verb:sync"
        "-source:appHostConfig=`"$Domain`",computerName=`"$Computer`",userName=`"$Username`",password=`"$Password`",authType=`"NTLM`""
        "-dest:appHostConfig=`"$Domain`""
        "-allowUntrusted"
        "-enableLink:AppPoolExtension"
    )
    
    if ($whatIfParam) {
        $msdeployArgs += $whatIfParam
    }

    # Log header
    $sanitizedArgs = $msdeployArgs -replace "password=`"[^`"]+`"", "password=`"***`""
    $logHeader = @"
========================================
Domain: $Domain
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Command: `"$MSDeployPath`" $($sanitizedArgs -join ' ')
========================================

"@
    $logHeader | Out-File -FilePath $LogFile -Encoding UTF8

    # Retry Loop
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $timestamp = Get-Date -Format "HH:mm:ss"
            "[$timestamp] Attempt $i of $MaxRetries..." | Out-File -FilePath $LogFile -Append -Encoding UTF8
            
            if ($i -gt 1) {
                Write-Host "Retry attempt $i for $Domain..." -ForegroundColor Yellow
            }

            # Execute MSDeploy
            $output = & $MSDeployPath $msdeployArgs 2>&1
            $output | Out-File -FilePath $LogFile -Append -Encoding UTF8
            
            if ($LASTEXITCODE -eq 0) {
                "[$timestamp] Exit Code: 0 (Success)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                return @{
                    Domain  = $Domain
                    Success = $true
                    Message = "Completed successfully"
                }
            }
            else {
                "[$timestamp] Exit Code: $LASTEXITCODE (Failed)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                if ($i -lt $MaxRetries) {
                    "[$timestamp] Waiting $RetryDelaySeconds seconds before retry..." | Out-File -FilePath $LogFile -Append -Encoding UTF8
                    Start-Sleep -Seconds $RetryDelaySeconds
                }
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            "[$timestamp] Error: $errorMsg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            if ($i -lt $MaxRetries) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }

    return @{
        Domain  = $Domain
        Success = $false
        Message = "Failed after $MaxRetries attempts. See log: $LogFile"
    }
}

#endregion

#region Worker Mode
if ($WorkerMode) {
    try {
        # Load credentials
        if (Test-Path $CredentialPath) {
            $Cred = Import-Clixml -Path $CredentialPath
            $Username = $Cred.UserName
            $Password = $Cred.GetNetworkCredential().Password
        }
        else {
            throw "Credential file not found: $CredentialPath"
        }

        Write-Host "Processing Domain: $WorkerDomain" -ForegroundColor Cyan
        Write-Host "Log Directory: $LogDir" -ForegroundColor Gray
        Write-Host "----------------------------------------"

        $result = Process-DomainItem `
            -Domain $WorkerDomain `
            -Computer $Computer `
            -Username $Username `
            -Password $Password `
            -LogDir $LogDir `
            -MSDeployPath $MSDeployPath `
            -WhatIf $EnableWhatIf

        if ($result.Success) {
            Write-ColorOutput "SUCCESS: $($result.Message)" -Type Success
            # Keep window open briefly to show success
            Start-Sleep -Seconds 3
            exit 0
        }
        else {
            Write-ColorOutput "FAILURE: $($result.Message)" -Type Error
            Write-Host "Press any key to close..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    }
    catch {
        Write-Error $_
        Write-Host "Press any key to close..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}
#endregion

#region Controller Mode (Main)

try {
    # Display script header
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  IIS Sites Pull Tool (Enhanced)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

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
    $Domains = Get-Content $DomainListFile -ErrorAction Stop | 
    Where-Object { $_.Trim() -ne "" -and !$_.TrimStart().StartsWith('#') } |
    ForEach-Object { $_.Trim() }
    
    if ($Domains.Count -eq 0) {
        Write-ColorOutput "No domains found in $DomainListFile" -Type Error
        exit 1
    }
    
    Write-ColorOutput "Found $($Domains.Count) domain(s) to process" -Type Success

    # Get credentials
    if (-not $Credential) {
        $Credential = Get-Credential -Message "Enter credentials for $Computer"
    }
    
    # Export credentials for workers/parallel jobs
    $TempCredFile = Join-Path $env:TEMP "iis_pull_cred_$PID.xml"
    $Credential | Export-Clixml -Path $TempCredFile
    
    # Ensure temp file cleanup
    try {
        if ($NewWindow) {
            Write-ColorOutput "Spawning new windows for each domain..." -Type Info
            
            $Domains | ForEach-Object -Parallel {
                param($Computer, $LogDir, $MSDeployPath, $EnableWhatIf, $TempCredFile, $MyInvocation)
                
                $domain = $_
                $scriptPath = $MyInvocation.MyCommand.Definition
                
                $workerArgs = @(
                    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"",
                    "-WorkerMode",
                    "-WorkerDomain", "`"$domain`"",
                    "-Computer", "`"$Computer`"",
                    "-LogDir", "`"$LogDir`"",
                    "-MSDeployPath", "`"$MSDeployPath`"",
                    "-CredentialPath", "`"$TempCredFile`""
                )
                if ($EnableWhatIf) {
                    $workerArgs += "-EnableWhatIf"
                }

                # Launch new process
                $process = Start-Process -FilePath "pwsh" -ArgumentList $workerArgs -PassThru -Wait
                
                if ($process.ExitCode -eq 0) {
                    Write-Host "[✓] $domain completed" -ForegroundColor Green
                }
                else {
                    Write-Host "[✗] $domain failed" -ForegroundColor Red
                }

            } -ArgumentList $Computer, $LogDir, $MSDeployPath, $EnableWhatIf, $TempCredFile, $MyInvocation -ThrottleLimit $MaxParallel
        }
        else {
            # Inline Parallel Execution
            # We need to pass the function definition to the parallel block
            $FunctionDef = Get-Content "function:\Process-DomainItem"
            
            $results = $Domains | ForEach-Object -Parallel {
                param($Computer, $LogDir, $MSDeployPath, $EnableWhatIf, $TempCredFile, $FunctionDef)
                
                # Re-define function in parallel runspace
                ${function:Process-DomainItem} = [scriptblock]::Create($FunctionDef)
                
                # Load creds
                $Cred = Import-Clixml -Path $TempCredFile
                $Username = $Cred.UserName
                $Password = $Cred.GetNetworkCredential().Password

                return Process-DomainItem `
                    -Domain $_ `
                    -Computer $Computer `
                    -Username $Username `
                    -Password $Password `
                    -LogDir $LogDir `
                    -MSDeployPath $MSDeployPath `
                    -WhatIf $EnableWhatIf

            } -ArgumentList $Computer, $LogDir, $MSDeployPath, $EnableWhatIf, $TempCredFile, $FunctionDef -ThrottleLimit $MaxParallel

            # Summary
            $successCount = ($results | Where-Object { $_.Success }).Count
            $failureCount = ($results | Where-Object { -not $_.Success }).Count
            
            Write-Host "`nExecution Summary" -ForegroundColor Cyan
            Write-ColorOutput "Successful: $successCount" -Type Success
            Write-ColorOutput "Failed: $failureCount" -Type $(if ($failureCount -gt 0) { 'Error' }else { 'Success' })
        }
    }
    finally {
        if (Test-Path $TempCredFile) {
            Remove-Item $TempCredFile -Force -ErrorAction SilentlyContinue
        }
    }
}
catch {
    Write-ColorOutput "Fatal error: $_" -Type Error
    exit 1
}

#endregion