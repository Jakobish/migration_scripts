#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module (Join-Path $PSScriptRoot "GuiHelpers.psm1")
Import-Module (Join-Path $PSScriptRoot "GuiStateHelpers.psm1")

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
$logFile = Join-Path $logDirectory ("gui-msdeploy-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

# ===============================================================
# DATA SOURCES
# ===============================================================

$verbs = @("sync", "dump", "delete", "getDependencies", "backup", "restore")

$sourceProviders = @("appHostConfig", "iisApp", "contentPath", "package", "dirPath", "filePath")
$destProviders = @("auto", "appHostConfig", "iisApp", "contentPath", "package", "dirPath", "filePath")

# provider main argument labels
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
$rules = @(
    "enableRule:DoNotDelete",
    "enableRule:DoNotDeleteRule",
    "disableRule:AppPool",
    "disableRule:FilePath"
)

# Link extensions
$enableLinks = @(
    "enableLink:AppPoolExtension",
    "enableLink:ContentExtension",
    "enableLink:CertificateExtension"
)

$disableLinks = @(
    "disableLink:AppPoolExtension",
    "disableLink:ContentExtension",
    "disableLink:CertificateExtension"
)

# Global flags
$flags = @(
    "-xml",
    "-allowUntrusted",
    "-whatIf",
    "-allowUntrusted",
    "-verbose"
)

. (Join-Path $PSScriptRoot "GuiLayout.ps1")

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
