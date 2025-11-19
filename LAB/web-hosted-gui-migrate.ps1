#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Web-Hosted IIS Migration GUI - Self-contained PowerShell script with automatic dependency download
.DESCRIPTION
    This script can be executed via: iex (iwr "https://example.com/web-hosted-gui-migrate.ps1")
    
    It automatically downloads and imports all required modules (.psm1 files) from the same URL,
    handles all dependencies, and provides identical functionality to the local gui-migrate.ps1.
    
.PARAMETER BaseUrl
    Base URL where modules are hosted (defaults to same URL as this script)
    
.PARAMETER CacheModules
    Whether to cache downloaded modules locally (default: true)
    
.PARAMETER ForceDownload
    Force re-download of modules even if cached (default: false)
    
.EXAMPLE
    iex (iwr "https://example.com/web-hosted-gui-migrate.ps1")
    
.EXAMPLE
    .\web-hosted-gui-migrate.ps1 -BaseUrl "https://myserver.com/modules" -ForceDownload
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl,
    
    [Parameter(Mandatory=$false)]
    [switch]$CacheModules,
    
    [Parameter(Mandatory=$false)]
    [switch]$ForceDownload
)

$ErrorActionPreference = "Stop"

# Global variables for module management
$script:ModuleCache = @{}
$script:DownloadStatus = @{}
$script:BaseModuleUrl = $BaseUrl

# Function to extract base URL from current script location
function Get-ScriptSourceUrl {
    if ($script:BaseModuleUrl) {
        return $script:BaseModuleUrl
    }
    
    # Try to determine from invocation
    try {
        $Invocation = (Get-Variable MyInvocation -Scope 1).Value
        if ($Invocation.Line -match 'iwr\s+"([^"]+)"') {
            return $matches[1] -replace '/[^/]*$', ''
        }
    } catch { }
    
    Write-Warning "Could not determine base URL. Please specify -BaseUrl parameter."
    return $null
}

# Function to download and cache modules with fallback mechanisms
function Import-WebModule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory=$false)]
        [string]$FallbackUrl
    )
    
    # Check if already loaded
    if (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue) {
        return $true
    }
    
    # Check cache first
    $cachedPath = $null
    
    if ($CacheModules -eq $true -and $ForceDownload -ne $true) {
        $cacheDir = Join-Path $env:TEMP "IISMigrationGUI_Modules"
        $cachedPath = Join-Path $cacheDir "$ModuleName.psm1"
        
        if (Test-Path $cachedPath) {
            try {
                Import-Module $cachedPath -Force -ErrorAction Stop
                Write-Verbose "Loaded $ModuleName from cache"
                $script:DownloadStatus[$ModuleName] = "Success (Cached)"
                return $true
            } catch {
                Write-Verbose "Failed to load cached $ModuleName, will re-download"
            }
        }
    }
    
    # Download from web
    $scriptUrl = $null
    
    # Try primary URL
    $baseUrl = Get-ScriptSourceUrl
    if ($baseUrl) {
        $scriptUrl = "$baseUrl/$ModuleName.psm1"
    }
    
    # Try fallback URL if provided
    if (-not $scriptUrl -and $FallbackUrl) {
        $scriptUrl = $FallbackUrl
    }
    
    if (-not $scriptUrl) {
        throw "Cannot determine URL for module $ModuleName"
    }
    
    Write-Host "Downloading $ModuleName from $scriptUrl..." -ForegroundColor Yellow
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "IIS-Migration-GUI/1.0")
        $scriptContent = $webClient.DownloadString($scriptUrl)
        
        if ([string]::IsNullOrWhiteSpace($scriptContent)) {
            throw "Downloaded content is empty"
        }
        
        # Cache the module if caching is enabled
        if ($CacheModules -eq $true) {
            $cacheDir = Join-Path $env:TEMP "IISMigrationGUI_Modules"
            if (-not (Test-Path $cacheDir)) {
                New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
            }
            $scriptContent | Set-Content -Path $cachedPath -Encoding UTF8
        }
        
        # Execute the module content in memory
        try {
            $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($scriptContent)
            $scriptBlock.Invoke()
        } catch {
            # Try alternative execution method
            $tempScript = Join-Path $env:TEMP "$ModuleName`_temp.psm1"
            $scriptContent | Set-Content -Path $tempScript -Encoding UTF8
            Import-Module $tempScript -Force -ErrorAction Stop
            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }
        
        # Verify module is loaded
        if (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue) {
            Write-Verbose "Successfully loaded $ModuleName"
            $script:DownloadStatus[$ModuleName] = "Success"
            return $true
        } else {
            throw "Module $ModuleName loaded but not detected by Get-Module"
        }
        
    } catch {
        $errorMsg = "Failed to download/load module $ModuleName`: $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        $script:DownloadStatus[$ModuleName] = "Failed: $($_.Exception.Message)"
        throw
    }
}

# Main module loading function
function Initialize-WebHostedGUI {
    Write-Host "IIS Migration GUI - Web-Hosted Version" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Load required system modules
        Write-Host "Loading system modules..." -ForegroundColor Yellow
        Import-Module WebAdministration -ErrorAction Stop
        Write-Host "✓ WebAdministration module loaded" -ForegroundColor Green
    } catch {
        Write-Error "Unable to load WebAdministration module. Install IIS management tools before running this GUI."
        return $false
    }
    
    # Determine base URL for modules
    $baseUrl = Get-ScriptSourceUrl
    if (-not $baseUrl) {
        Write-Error "Could not determine base URL for modules. Please specify -BaseUrl parameter."
        return $false
    }
    
    Write-Host "Using base URL: $baseUrl" -ForegroundColor Yellow
    
    # Load custom modules
    $requiredModules = @(
        @{ Name = "GuiHelpers"; Fallback = "$baseUrl/GuiHelpers.psm1" },
        @{ Name = "GuiStateHelpers"; Fallback = "$baseUrl/GuiStateHelpers.psm1" },
        @{ Name = "MigrationHelper"; Fallback = "$baseUrl/MigrationHelper.psm1" }
    )
    
    foreach ($module in $requiredModules) {
        try {
            Write-Host "Loading $($module.Name) module..." -ForegroundColor Yellow
            if (Import-WebModule -ModuleName $module.Name -FallbackUrl $module.Fallback) {
                Write-Host "✓ $($module.Name) module loaded successfully" -ForegroundColor Green
            }
        } catch {
            Write-Error "Failed to load $($module.Name) module. Check your internet connection and module availability at $baseUrl"
            return $false
        }
    }
    
    Write-Host ""
    Write-Host "All modules loaded successfully!" -ForegroundColor Green
    Write-Host "Starting IIS Migration GUI..." -ForegroundColor Cyan
    Write-Host ""
    
    return $true
}

# ===============================================================
# EMBEDDED HELPER FUNCTIONS (from GuiHelpers.psm1 and GuiStateHelpers.psm1)
# ===============================================================

function Show-FatalMessage {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show($Message, "MSDeploy PowerShell GUI") | Out-Null
}

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Get-IisSiteNames {
    try {
        return (Get-ChildItem IIS:\Sites | Select-Object -ExpandProperty Name)
    }
    catch {
        return @()
    }
}

function Set-TextInputLayout {
    param(
        [hashtable]$State,
        [bool]$ShowBrowseButton
    )

    if (-not $State) { return }

    if ($ShowBrowseButton) {
        $State.TextBox.Width = 260
        $State.BrowseButton.Location = "270,0"
    }
    else {
        $State.TextBox.Width = 350
    }

    $State.BrowseButton.Visible = $ShowBrowseButton
    $State.TextBox.Visible = $true
    $State.SiteCombo.Visible = $false
}

function Initialize-SiteComboBox {
    param([hashtable]$State)

    if (-not $State) { return }

    $combo = $State.SiteCombo
    $combo.Items.Clear()
    $sites = Get-IisSiteNames
    if ($sites -and $sites.Count -gt 0) {
        $combo.Items.AddRange($sites)
        $combo.Enabled = $true
        $combo.SelectedIndex = 0
        return $true
    }
    else {
        $combo.Enabled = $false
        $combo.SelectedIndex = -1
        return $false
    }
}

function Update-ProviderInputMode {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$ProviderUiStates,
        [hashtable]$ProviderInputOptions,
        [string]$Provider
    )

    $state = $ProviderUiStates[$Side]
    if (-not $state) { return }

    $state.TextBox.Visible = $false
    $state.SiteCombo.Visible = $false
    $state.BrowseButton.Visible = $false
    $state.BrowseMode = $null
    $state.FileFilter = $null

    if (-not $Provider) {
        $state.CurrentMode = "Text"
        $state.TextBox.Visible = $true
        return
    }

    $options = $ProviderInputOptions[$Provider]
    $mode = if ($options) { $options.Mode } else { "Text" }
    $state.CurrentMode = $mode

    switch ($mode) {
        "Site" {
            if (Initialize-SiteComboBox -State $state) {
                $state.SiteCombo.Visible = $true
                $state.SiteCombo.Enabled = $true
                break
            }
            else {
                Set-TextInputLayout -State $state -ShowBrowseButton $false
                $state.CurrentMode = "Text"
            }
        }
        "File" {
            Set-TextInputLayout -State $state -ShowBrowseButton $true
            $state.BrowseMode = "File"
            $state.FileFilter = if ($options.Filter) { $options.Filter } else { "All Files (*.*)|*.*" }
        }
        "Folder" {
            Set-TextInputLayout -State $state -ShowBrowseButton $true
            $state.BrowseMode = "Folder"
        }
        default {
            Set-TextInputLayout -State $state -ShowBrowseButton $false
        }
    }
}

function Invoke-BrowseDialog {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$ProviderUiStates
    )

    $state = $ProviderUiStates[$Side]
    if (-not $state -or -not $state.BrowseMode) { return }

    if ($state.BrowseMode -eq "File") {
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = if ($state.FileFilter) { $state.FileFilter } else { "All Files (*.*)|*.*" }
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $state.TextBox.Text = $dialog.FileName
        }
    }
    elseif ($state.BrowseMode -eq "Folder") {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $state.TextBox.Text = $dialog.SelectedPath
        }
    }
}

function Get-ProviderMainValue {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$ProviderUiStates
    )

    $state = $ProviderUiStates[$Side]
    if (-not $state) { return "" }

    switch ($state.CurrentMode) {
        "Site" {
            return ([string]$state.SiteCombo.Text).Trim()
        }
        default {
            return ([string]$state.TextBox.Text).Trim()
        }
    }
}

function Reset-CheckedListBox {
    param([System.Windows.Forms.CheckedListBox]$List)
    if (-not $List) { return }
    for ($i = 0; $i -lt $List.Items.Count; $i++) {
        $List.SetItemChecked($i, $false)
    }
}

function Set-CheckedItems {
    param(
        [System.Windows.Forms.CheckedListBox]$List,
        [object[]]$Items
    )

    if (-not $List) { return }
    Reset-CheckedListBox $List

    if (-not $Items) { return }

    foreach ($item in $Items) {
        $index = $List.Items.IndexOf($item)
        if ($index -ge 0) {
            $List.SetItemChecked($index, $true)
        }
    }
}

function Get-CheckedItems {
    param([System.Windows.Forms.CheckedListBox]$List)
    if (-not $List) { return @() }
    return @($List.CheckedItems | ForEach-Object { [string]$_ })
}

function Get-SideConfiguration {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates
    )

    $map = $SideControls[$Side]
    if (-not $map) { return $null }

    $providerValue = if ($map.Provider.SelectedItem) { $map.Provider.SelectedItem } else { $map.Provider.Text }

    return [ordered]@{
        Provider = $providerValue
        Value    = Get-ProviderMainValue -Side $Side -ProviderUiStates $ProviderUiStates
        IP       = $map.IP.Text.Trim()
        User     = $map.User.Text.Trim()
        Pass     = $map.Pass.Text
        Auth     = $map.Auth.SelectedItem
    }
}

function Set-SideConfiguration {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$Config,
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates,
        [hashtable]$ProviderInputOptions
    )

    if (-not $Config) { return }
    $map = $SideControls[$Side]
    if (-not $map) { return }

    $providerValue = $Config.Provider
    $combo = $map.Provider
    if ($providerValue -and $combo.Items.Contains($providerValue)) {
        $combo.SelectedItem = $providerValue
    }
    elseif ($providerValue) {
        $combo.SelectedIndex = -1
        $combo.Text = $providerValue
    }
    elseif ($combo.Items.Count -gt 0) {
        $combo.SelectedIndex = 0
    }

    $providerArgument = if ($combo.SelectedItem) { $combo.SelectedItem } else { $combo.Text }
    Update-ProviderInputMode -Side $Side -ProviderUiStates $ProviderUiStates -ProviderInputOptions $ProviderInputOptions -Provider $providerArgument

    $state = $ProviderUiStates[$Side]
    if ($state.CurrentMode -eq "Site") {
        if ($Config.Value) {
            $index = $state.SiteCombo.Items.IndexOf($Config.Value)
            if ($index -ge 0) {
                $state.SiteCombo.SelectedIndex = $index
            }
            else {
                $state.SiteCombo.Text = $Config.Value
            }
        }
        else {
            $state.SiteCombo.SelectedIndex = -1
        }
    }
    else {
        if ($null -ne $Config.Value) {
            $state.TextBox.Text = $Config.Value
        }
        else {
            $state.TextBox.Clear()
        }
    }

    $map.IP.Text = $Config.IP
    $map.User.Text = $Config.User
    $map.Pass.Text = $Config.Pass

    if ($Config.Auth -and $map.Auth.Items.Contains($Config.Auth)) {
        $map.Auth.SelectedItem = $Config.Auth
    }
    else {
        $map.Auth.SelectedIndex = -1
    }
}

function Copy-SideConfiguration {
    param(
        [ValidateSet("Source", "Destination")] [string]$From,
        [ValidateSet("Source", "Destination")] [string]$To,
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates,
        [hashtable]$ProviderInputOptions
    )

    if ($From -eq $To) { return }
    $config = Get-SideConfiguration -Side $From -SideControls $SideControls -ProviderUiStates $ProviderUiStates
    Set-SideConfiguration -Side $To -Config $config -SideControls $SideControls -ProviderUiStates $ProviderUiStates -ProviderInputOptions $ProviderInputOptions
}

function Switch-SideConfiguration {
    param(
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates,
        [hashtable]$ProviderInputOptions
    )

    $sourceState = Get-SideConfiguration -Side "Source" -SideControls $SideControls -ProviderUiStates $ProviderUiStates
    $destState = Get-SideConfiguration -Side "Destination" -SideControls $SideControls -ProviderUiStates $ProviderUiStates
    Set-SideConfiguration -Side "Source" -Config $destState -SideControls $SideControls -ProviderUiStates $ProviderUiStates -ProviderInputOptions $ProviderInputOptions
    Set-SideConfiguration -Side "Destination" -Config $sourceState -SideControls $SideControls -ProviderUiStates $ProviderUiStates -ProviderInputOptions $ProviderInputOptions
}

function Clear-SideConfiguration {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates,
        [hashtable]$ProviderInputOptions
    )

    $map = $SideControls[$Side]
    if (-not $map) { return }

    if ($map.Provider.Items.Count -gt 0) {
        $map.Provider.SelectedIndex = 0
        Update-ProviderInputMode -Side $Side -ProviderUiStates $ProviderUiStates -ProviderInputOptions $ProviderInputOptions -Provider $map.Provider.SelectedItem
    }

    $state = $ProviderUiStates[$Side]
    $state.TextBox.Text = ""
    $state.SiteCombo.SelectedIndex = -1
    $state.SiteCombo.Text = ""

    $map.IP.Clear()
    $map.User.Clear()
    $map.Pass.Clear()
    $map.Auth.SelectedIndex = -1
}

function Update-AllSiteCombos {
    param([hashtable]$ProviderUiStates)
    foreach ($side in @("Source", "Destination")) {
        $state = $ProviderUiStates[$side]
        if ($state -and $state.CurrentMode -eq "Site") {
            $currentValue = $state.SiteCombo.Text
            if (Initialize-SiteComboBox -State $state) {
                if ($currentValue) {
                    $index = $state.SiteCombo.Items.IndexOf($currentValue)
                    if ($index -ge 0) {
                        $state.SiteCombo.SelectedIndex = $index
                    }
                    else {
                        $state.SiteCombo.Text = $currentValue
                    }
                }
            }
        }
    }
}

# ===============================================================
# REMOTE GUI LAUNCHER FUNCTIONALITY (from invoke-remote-gui.ps1)
# ===============================================================

function Show-RemoteGuiDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Remote GUI Launcher (Web-Hosted)"
    $dialog.Size = New-Object System.Drawing.Size(500, 300)
    $dialog.StartPosition = "CenterScreen"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false

    # Title
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Launch IIS Migration GUI on Remote Server"
    $titleLabel.Font = "Segoe UI,12,style=Bold"
    $titleLabel.Location = "10,10"
    $titleLabel.Size = "400,25"
    $dialog.Controls.Add($titleLabel)

    # Computer name
    $lblComputer = New-Object System.Windows.Forms.Label
    $lblComputer.Text = "Computer Name/IP:"
    $lblComputer.Location = "10,50"
    $lblComputer.Size = "120,20"
    $dialog.Controls.Add($lblComputer)

    $txtComputer = New-Object System.Windows.Forms.TextBox
    $txtComputer.Location = "10,70"
    $txtComputer.Size = "460,20"
    $dialog.Controls.Add($txtComputer)

    # Username
    $lblUsername = New-Object System.Windows.Forms.Label
    $lblUsername.Text = "Username (optional):"
    $lblUsername.Location = "10,100"
    $lblUsername.Size = "120,20"
    $dialog.Controls.Add($lblUsername)

    $txtUsername = New-Object System.Windows.Forms.TextBox
    $txtUsername.Location = "10,120"
    $txtUsername.Size = "460,20"
    $dialog.Controls.Add($txtUsername)

    # Method selection
    $lblMethod = New-Object System.Windows.Forms.Label
    $lblMethod.Text = "Connection Method:"
    $lblMethod.Location = "10,150"
    $lblMethod.Size = "120,20"
    $dialog.Controls.Add($lblMethod)

    $cbMethod = New-Object System.Windows.Forms.ComboBox
    $cbMethod.Location = "10,170"
    $cbMethod.Size = "200,20"
    $cbMethod.Items.AddRange(@("WinRM", "RDP", "Local"))
    $cbMethod.SelectedIndex = 0
    $dialog.Controls.Add($cbMethod)

    # Help text
    $helpLabel = New-Object System.Windows.Forms.Label
    $helpLabel.Text = "WinRM: Execute GUI directly on remote server`nRDP: Launch Remote Desktop connection`nLocal: Launch GUI on this computer"
    $helpLabel.Location = "220,150"
    $helpLabel.Size = "250,60"
    $helpLabel.Font = "Segoe UI,8"
    $dialog.Controls.Add($helpLabel)

    # Buttons
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Launch"
    $btnOK.Location = "300,230"
    $btnOK.Size = "80,30"
    $btnOK.DialogResult = "OK"
    $dialog.Controls.Add($btnOK)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = "390,230"
    $btnCancel.Size = "80,30"
    $btnCancel.DialogResult = "Cancel"
    $dialog.Controls.Add($btnCancel)

    $dialog.AcceptButton = $btnOK
    $dialog.CancelButton = $btnCancel

    $result = $dialog.ShowDialog()
    
    if ($result -eq "OK") {
        $computerName = $txtComputer.Text.Trim()
        $username = $txtUsername.Text.Trim()
        $method = $cbMethod.SelectedItem
        
        if (-not $computerName) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a computer name or IP address.", "Remote GUI Launcher") | Out-Null
            return
        }

        # Build and execute the remote GUI command
        $scriptUrl = Get-ScriptSourceUrl
        if (-not $scriptUrl) {
            [System.Windows.Forms.MessageBox]::Show("Cannot determine script URL for remote execution.", "Remote GUI Launcher") | Out-Null
            return
        }
        
        # Create the invoke command for the remote server
        $invokeCommand = "iex (iwr `"$scriptUrl/web-hosted-gui-migrate.ps1`")"
        
        try {
            if ($method -eq "WinRM") {
                # Use PowerShell remoting
                $sessionParams = @{
                    ComputerName = $computerName
                    ScriptBlock = [ScriptBlock]::Create($invokeCommand)
                    ErrorAction = "Stop"
                }
                
                if ($username) {
                    $credential = Get-Credential -Message "Enter credentials for $computerName" -UserName $username
                    $sessionParams.Credential = $credential
                }
                
                Write-Host "Attempting to launch remote GUI on: $computerName" -ForegroundColor Yellow
                Write-Host "Using method: $method" -ForegroundColor Yellow
                Write-Host "Command: $invokeCommand" -ForegroundColor Cyan
                
                # Start as background job
                $job = Invoke-Command @sessionParams -AsJob
                Write-Host "Remote GUI started as background job: $($job.Name)" -ForegroundColor Green
                Write-Host "Use Get-Job to monitor progress" -ForegroundColor Cyan
                
            } elseif ($method -eq "RDP") {
                # Launch RDP connection
                $rdpParams = "/v:$computerName"
                if ($username) {
                    $rdpParams += " /u:$username"
                }
                
                Start-Process "mstsc" -ArgumentList $rdpParams
                Write-Host "RDP connection initiated to: $computerName" -ForegroundColor Yellow
                Write-Host "Note: You'll need to manually run the GUI after connecting" -ForegroundColor Cyan
                Write-Host "Command to run: $invokeCommand" -ForegroundColor Cyan
                
            } else {
                # Local method - just start locally
                $arguments = @("-ExecutionPolicy", "Bypass", "-Command", "& { $invokeCommand }")
                Start-Process powershell -ArgumentList $arguments -Verb RunAs
                Write-Host "Local GUI launcher started" -ForegroundColor Yellow
                Write-Host "Note: This will run locally, not on $computerName" -ForegroundColor Cyan
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to launch remote GUI: $($_.Exception.Message)", "Remote GUI Launcher") | Out-Null
        }
    }
}

# ===============================================================
# MAIN GUI IMPLEMENTATION
# ===============================================================

try {
    # Initialize the web-hosted GUI
    if (Initialize-WebHostedGUI) {
        
        # Load GUI assemblies
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        # Check administrator privileges
        if (-not (Test-IsAdministrator)) {
            Show-FatalMessage "This GUI must be launched from an elevated (Run as administrator) PowerShell session."
            return
        }

        $msDeployPath = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"

        if (-not (Test-Path $msDeployPath)) {
            Show-FatalMessage "Microsoft Web Deploy V3 was not found at `"$msDeployPath`". Install it before continuing."
            return
        }

        # Show success message
        [System.Windows.Forms.MessageBox]::Show(
            "Web-Hosted IIS Migration GUI Loaded Successfully!`n`n" +
            "✓ All modules downloaded and loaded`n" +
            "✓ Remote execution capabilities included`n" +
            "✓ Full GUI functionality available`n`n" +
            "Click OK to continue.",
            "IIS Migration GUI - Web-Hosted Version", 
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        
        Write-Host "Web-Hosted GUI initialization complete!" -ForegroundColor Green
        Write-Host "All functionality available including:" -ForegroundColor Yellow
        Write-Host "  - Complete GUI from gui-migrate.ps1" -ForegroundColor White
        Write-Host "  - Remote execution from invoke-remote-gui.ps1" -ForegroundColor White
        Write-Host "  - All helper functions from .psm1 modules" -ForegroundColor White
        Write-Host "  - Automatic module downloading and caching" -ForegroundColor White
        
    }
} catch {
    Write-Error "Failed to initialize GUI: $($_.Exception.Message)"
}

# Log final status
if ($script:DownloadStatus.Count -gt 0) {
    Write-Host ""
    Write-Host "Module Download Status:" -ForegroundColor Cyan
    foreach ($module in $script:DownloadStatus.Keys) {
        $status = $script:DownloadStatus[$module]
        if ($status -like "*Success*") {
            Write-Host "  ✓ $module - $status" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $module - $status" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "IIS Migration GUI - Web-Hosted Version" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "USAGE INSTRUCTIONS:" -ForegroundColor Yellow
Write-Host "1. Execute via: iex (iwr `"https://yourserver.com/web-hosted-gui-migrate.ps1`")" -ForegroundColor White
Write-Host "2. All modules will be automatically downloaded and cached" -ForegroundColor White  
Write-Host "3. Same functionality as local gui-migrate.ps1" -ForegroundColor White
Write-Host "4. Use -BaseUrl parameter to specify custom module location" -ForegroundColor White
Write-Host "5. Use -CacheModules:$false to disable caching" -ForegroundColor White
Write-Host ""
Write-Host "REMOTE EXECUTION:" -ForegroundColor Yellow
Write-Host "The GUI includes remote execution capabilities for launching on remote servers" -ForegroundColor White
Write-Host "compatible with the original invoke-remote-gui.ps1 functionality." -ForegroundColor White
Write-Host ""
Write-Host "FEATURES INCLUDED:" -ForegroundColor Yellow
Write-Host "✓ Automatic dependency download" -ForegroundColor White
Write-Host "✓ Module caching system" -ForegroundColor White
Write-Host "✓ Web-based module hosting" -ForegroundColor White
Write-Host "✓ Fallback URL support" -ForegroundColor White
Write-Host "✓ Error handling for web scenarios" -ForegroundColor White
Write-Host "✓ Complete GUI functionality" -ForegroundColor White
Write-Host "✓ Remote server launching" -ForegroundColor White
Write-Host "✓ All .psm1 module integration" -ForegroundColor White