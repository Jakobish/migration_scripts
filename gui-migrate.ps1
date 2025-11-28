#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module (Join-Path $PSScriptRoot "lib\GuiHelpers.psm1")
Import-Module (Join-Path $PSScriptRoot "lib\GuiStateHelpers.psm1")

try {
    Import-Module WebAdministration -ErrorAction Stop
}
catch {
    Show-FatalMessage "Unable to load WebAdministration module. Install IIS management tools before running this GUI."
    return
}

if (-not (Test-IsAdministrator)) {
    Show-FatalMessage "This GUI must be launched from an elevated (Run as administrator) PowerShell session."
    return
}

function Get-MsDeployPath {
    $paths = @(
        "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe",
        "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

$msDeployPath = Get-MsDeployPath

if (-not $msDeployPath) {
    Show-FatalMessage "Microsoft Web Deploy V3 was not found. Install it before continuing."
    return
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logDirectory = Join-Path $scriptRoot "site-logs"
if (-not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}

# ===============================================================
# DATA SOURCES
# ===============================================================
# Note: Variables below are used via dot-sourcing in GuiLayout.ps1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$verbs = @("sync", "dump", "delete", "getDependencies", "backup", "restore")

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$sourceProviders = @("appHostConfig", "iisApp", "contentPath", "package", "dirPath", "filePath")
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$destProviders = @("auto", "appHostConfig", "iisApp", "contentPath", "package", "dirPath", "filePath")

# provider main argument labels
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$providerMainValueLabel = @{
    "appHostConfig" = "Site Name:"
    "iisApp"        = "IIS App Path:"
    "contentPath"   = "Folder Path:"
    "package"       = "Package File:"
    "dirPath"       = "Directory Path:"
    "filePath"      = "File Path:"
    "auto"          = "Main Value (optional):"
}



# Helper to retrieve IIS site names for dropdowns
function Get-IisSiteNames {
    try {
        return (Get-ChildItem IIS:\Sites | Select-Object -ExpandProperty Name)
    }
    catch {
        return @()
    }
}

# Deployment rules
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$rules = @(
    "enableRule:DoNotDelete",
    "enableRule:DoNotDeleteRule",
    "disableRule:AppPool",
    "disableRule:FilePath"
)

# Link extensions
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$enableLinks = @(
    "enableLink:AppPoolExtension",
    "enableLink:ContentExtension",
    "enableLink:CertificateExtension"
)

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$disableLinks = @(
    "disableLink:AppPoolExtension",
    "disableLink:ContentExtension",
    "disableLink:CertificateExtension"
)

# Global flags
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
$flags = @(
    "-xml",
    "-allowUntrusted",
    "-whatIf",
    "-verbose"
)

# ===============================================================
# CORE GUI FUNCTIONS
# ===============================================================

function Update-Command {
    # Build the msdeploy.exe command based on current GUI state
    $verb = $cbVerb.SelectedItem
    if (-not $verb) { $verb = "sync" }
    
    # Get source configuration
    $srcProvider = $cbSrcProv.SelectedItem
    $srcValue = Get-ProviderMainValue -Side "Source" -ProviderUiStates $providerUiStates
    
    # Get destination configuration
    $dstProvider = $cbDstProv.SelectedItem
    $dstValue = Get-ProviderMainValue -Side "Destination" -ProviderUiStates $providerUiStates
    
    # Build source argument
    $sourceArg = "-source:$srcProvider"
    if ($srcValue) { $sourceArg += "=`"$srcValue`"" }
    if ($txtSrcIP.Text.Trim()) { $sourceArg += ",computerName=`"$($txtSrcIP.Text.Trim())`"" }
    if ($txtSrcUser.Text.Trim()) { $sourceArg += ",userName=`"$($txtSrcUser.Text.Trim())`"" }
    if ($txtSrcPass.Text) { $sourceArg += ",password=`"$($txtSrcPass.Text)`"" }
    if ($cbSrcAuth.SelectedItem) { $sourceArg += ",authType=`"$($cbSrcAuth.SelectedItem)`"" }
    
    # Build destination argument
    $destArg = "-dest:$dstProvider"
    if ($dstValue) { $destArg += "=`"$dstValue`"" }
    if ($txtDstIP.Text.Trim()) { $destArg += ",computerName=`"$($txtDstIP.Text.Trim())`"" }
    if ($txtDstUser.Text.Trim()) { $destArg += ",userName=`"$($txtDstUser.Text.Trim())`"" }
    if ($txtDstPass.Text) { $destArg += ",password=`"$($txtDstPass.Text)`"" }
    if ($cbDstAuth.SelectedItem) { $destArg += ",authType=`"$($cbDstAuth.SelectedItem)`"" }
    
    # Build command parts
    $parts = @("`"$msDeployPath`"", "-verb:$verb", $sourceArg, $destArg)
    
    # Add checked flags
    $checkedFlags = Get-CheckedItems $lstFlags
    foreach ($flag in $checkedFlags) {
        $parts += $flag
    }
    
    # Add checked rules
    $checkedRules = Get-CheckedItems $lstRules
    foreach ($rule in $checkedRules) {
        $parts += "-$rule"
    }
    
    # Add checked enable links
    $checkedELinks = Get-CheckedItems $lstELinks
    foreach ($link in $checkedELinks) {
        $parts += "-$link"
    }
    
    # Add checked disable links
    $checkedDLinks = Get-CheckedItems $lstDLinks
    foreach ($link in $checkedDLinks) {
        $parts += "-$link"
    }
    
    # Update command preview
    $cmdBox.Text = ($parts -join " ")
}

function Clear-AllInputs {
    # Clear source and destination configurations
    Clear-SideConfiguration -Side "Source" -SideControls $sideControls -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions
    Clear-SideConfiguration -Side "Destination" -SideControls $sideControls -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions
    
    # Reset verb to first item
    if ($cbVerb.Items.Count -gt 0) {
        $cbVerb.SelectedIndex = 0
    }
    
    # Uncheck all lists
    Reset-CheckedListBox $lstFlags
    Reset-CheckedListBox $lstRules
    Reset-CheckedListBox $lstELinks
    Reset-CheckedListBox $lstDLinks
    
    # Clear log
    $logBox.Clear()
    
    # Update command preview
    Update-Command
}

function Invoke-MsDeployCommand {
    param([switch]$DryRun)
    
    $command = $cmdBox.Text.Trim()
    if (-not $command) {
        $logBox.AppendText("[ERROR] No command to execute.`r`n")
        return
    }
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logBox.AppendText("[$timestamp] Starting execution...`r`n")
        
        if ($DryRun) {
            $logBox.AppendText("[DRY RUN] Would execute: $command`r`n")
        }
        else {
            # Parse command - first item is exe path, rest are arguments
            $parts = $command -split ' (?=-)' # Split on space before dashes
            $exePath = $parts[0].Trim('"')
            $arguments = $parts[1..($parts.Length - 1)] -join ' '
            
            $logBox.AppendText("[INFO] Executing msdeploy.exe...`r`n")
            
            # Execute command and capture output
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $exePath
            $psi.Arguments = $arguments
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            $process.Start() | Out-Null
            
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            
            if ($stdout) {
                $logBox.AppendText($stdout + "`r`n")
            }
            if ($stderr) {
                $logBox.AppendText("[ERROR] $stderr`r`n")
            }
            
            $logBox.AppendText("[INFO] Exit code: $($process.ExitCode)`r`n")
            
            if ($process.ExitCode -eq 0) {
                $logBox.AppendText("[SUCCESS] Command completed successfully.`r`n")
            }
            else {
                $logBox.AppendText("[ERROR] Command failed with exit code $($process.ExitCode).`r`n")
            }
        }
    }
    catch {
        $logBox.AppendText("[ERROR] Exception: $($_.Exception.Message)`r`n")
    }
}

function Show-RemoteGuiDialog {
    [System.Windows.Forms.MessageBox]::Show(
        "Remote GUI functionality is not yet implemented.`r`n`r`nThis feature would allow you to launch this GUI on a remote server via PSRemoting.",
        "Remote GUI - Not Implemented",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

# Load UI layout and capture returned components
$layoutComponents = . (Join-Path $PSScriptRoot "lib\GuiLayout.ps1")

# Extract UI controls
$form = $layoutComponents.Form
$lstFlags = $layoutComponents.Flags
$lstRules = $layoutComponents.Rules
$lstELinks = $layoutComponents.EnableLinks
$lstDLinks = $layoutComponents.DisableLinks
$sideControls = $layoutComponents.SideControls
$cbVerb = $layoutComponents.VerbCombo
$cbSrcProv = $layoutComponents.SrcProvider
$txtSrcMain = $layoutComponents.SrcMain
$cbSrcSites = $layoutComponents.SrcSites
$txtSrcIP = $layoutComponents.SrcIP
$txtSrcUser = $layoutComponents.SrcUser
$txtSrcPass = $layoutComponents.SrcPass
$cbSrcAuth = $layoutComponents.SrcAuth
$cbDstProv = $layoutComponents.DstProvider
$txtDstMain = $layoutComponents.DstMain
$cbDstSites = $layoutComponents.DstSites
$txtDstIP = $layoutComponents.DstIP
$txtDstUser = $layoutComponents.DstUser
$txtDstPass = $layoutComponents.DstPass
$cbDstAuth = $layoutComponents.DstAuth
$cmdBox = $layoutComponents.CmdBox
$logBox = $layoutComponents.LogBox

# Re-attach event handlers for updates
foreach ($ctl in @($cbVerb, $cbSrcProv, $cbDstProv, $cbSrcAuth, $cbDstAuth, $cbSrcSites, $cbDstSites)) {
    $ctl.Add_TextChanged({ Update-Command }) 2>$null
    $ctl.Add_SelectedIndexChanged({ Update-Command }) 2>$null
}

foreach ($ctl in @($txtSrcMain, $txtDstMain, $txtSrcIP, $txtSrcUser, $txtSrcPass, $txtDstIP, $txtDstUser, $txtDstPass)) {
    $ctl.Add_TextChanged({ Update-Command }) 2>$null
}

foreach ($ctl in @($lstFlags, $lstRules, $lstELinks, $lstDLinks)) {
    $ctl.Add_SelectedIndexChanged({ Update-Command }) 2>$null
    $ctl.Add_ItemCheck({ Start-Sleep -Milliseconds 100; Update-Command }) 2>$null
}

# Initialize


$form.Add_Shown({ Update-Command })
$form.ShowDialog()
