#Requires -RunAsAdministrator
Import-Module WebAdministration
Import-Module (Join-Path $PSScriptRoot "MigrationHelper.psm1")

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

$msDeployPath = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"

if (-not (Test-Path $msDeployPath)) {
    Show-FatalMessage "Microsoft Web Deploy V3 was not found at `"$msDeployPath`". Install it before continuing."
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

$providerInputOptions = @{
    "appHostConfig" = @{ Mode = "Site" }
    "contentPath"   = @{ Mode = "Folder" }
    "dirPath"       = @{ Mode = "Folder" }
    "filePath"      = @{ Mode = "File" }
    "package"       = @{
        Mode   = "File"
        Filter = "MSDeploy Packages (*.zip)|*.zip|All Files (*.*)|*.*"
    }
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

# ===============================================================
# CREATE MAIN FORM
# ===============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "MSDeploy PowerShell GUI"
$form.Size = New-Object System.Drawing.Size(1400, 1250)
$form.StartPosition = "CenterScreen"

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.ShowAlways = $true

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = "10,10"
$headerPanel.Size = "1130,140"
$headerPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($headerPanel)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Dual-Sided MSDeploy Command Builder"
$titleLabel.Font = "Segoe UI,12,style=Bold"
$titleLabel.Location = "10,5"
$titleLabel.AutoSize = $true
$headerPanel.Controls.Add($titleLabel)

$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Text = "Build identical source/destination definitions, then execute or copy the msdeploy command.  " +
    "Use the helper buttons to mirror, swap, or refresh either side so you can start from whichever server you prefer."
$infoLabel.Location = "10,35"
$infoLabel.Size = "780,80"
$headerPanel.Controls.Add($infoLabel)

$actionPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$actionPanel.Location = "800,5"
$actionPanel.Size = "320,130"
$actionPanel.FlowDirection = "TopDown"
$actionPanel.WrapContents = $false
$actionPanel.AutoScroll = $true
$headerPanel.Controls.Add($actionPanel)

function New-ActionButton {
    param(
        [string]$Text,
        [string]$TooltipText
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Width = 300
    $btn.Height = 25
    if ($TooltipText) {
        $toolTip.SetToolTip($btn, $TooltipText)
    }
    return $btn
}

$btnCopySrcToDst = New-ActionButton -ToolTip $toolTip -Text "Copy Source → Destination" -TooltipText "Mirror all fields from the left side to the right side."
$btnCopyDstToSrc = New-ActionButton -ToolTip $toolTip -Text "Copy Destination → Source" -TooltipText "Mirror all fields from the right side to the left side."
$btnSwapSides = New-ActionButton -ToolTip $toolTip -Text "Swap Source & Destination" -TooltipText "Exchange both sides so you can easily reverse a migration."
$btnRefreshSites = New-ActionButton -ToolTip $toolTip -Text "Refresh IIS Site Lists" -TooltipText "Reload local IIS site names for both provider pickers."
$btnClearAll = New-ActionButton -ToolTip $toolTip -Text "Clear Everything" -TooltipText "Reset all inputs, lists, and preview text."
$btnSaveState = New-ActionButton -ToolTip $toolTip -Text "Save Layout (JSON/XML)" -TooltipText "Persist the current inputs to a JSON or XML file."
$btnLoadState = New-ActionButton -ToolTip $toolTip -Text "Load Layout (JSON/XML)" -TooltipText "Load inputs from a previously saved JSON or XML file."

$actionPanel.Controls.Add($btnCopySrcToDst)
$actionPanel.Controls.Add($btnCopyDstToSrc)
$actionPanel.Controls.Add($btnSwapSides)
$actionPanel.Controls.Add($btnRefreshSites)
$actionPanel.Controls.Add($btnClearAll)
$actionPanel.Controls.Add($btnSaveState)
$actionPanel.Controls.Add($btnLoadState)

$btnCopySrcToDst.Add_Click({ Copy-SideConfigurationLocal -From "Source" -To "Destination" })
$btnCopyDstToSrc.Add_Click({ Copy-SideConfigurationLocal -From "Destination" -To "Source" })
$btnSwapSides.Add_Click({ Switch-SideConfigurationLocal })
$btnRefreshSites.Add_Click({ Update-AllSiteCombosLocal; Update-Command })
$btnClearAll.Add_Click({ Clear-AllInputs })
$btnSaveState.Add_Click({
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Filter = "JSON files (*.json)|*.json|XML files (*.xml)|*.xml|All files (*.*)|*.*"
        $dialog.DefaultExt = "json"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Save-GuiState -Path $dialog.FileName
        }
    })
$btnLoadState.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "JSON files (*.json)|*.json|XML files (*.xml)|*.xml|All files (*.*)|*.*"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Load-GuiState -Path $dialog.FileName
        }
    })

# ===============================================================
# COMMON VERB CONFIGURATION
# ===============================================================

$lblVerb = New-Object System.Windows.Forms.Label
$lblVerb.Text = "Verb:"
$lblVerb.Location = "10,900"
$lblVerb.Font = "Arial,10,style=Bold"
$form.Controls.Add($lblVerb)

$cbVerb = New-Object System.Windows.Forms.ComboBox
$cbVerb.Location = "150,895"
$cbVerb.Width = 350
$cbVerb.Items.AddRange($verbs)
$cbVerb.SelectedIndex = 0
$form.Controls.Add($cbVerb)

# ===============================================================
# LEFT PANEL (SOURCE)
# ===============================================================

$left = New-Object System.Windows.Forms.Panel
$left.Location = "10,160"
$left.Size = "560,720"
$left.BorderStyle = "FixedSingle"
$form.Controls.Add($left)

$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Text = "SOURCE CONFIGURATION"
$lblSource.Font = "Arial,10,style=Bold"
$lblSource.Location = "10,10"
$left.Controls.Add($lblSource)

# Source provider
$lblSrcProv = New-Object System.Windows.Forms.Label
$lblSrcProv.Text = "Source Provider:"
$lblSrcProv.Location = "10,50"
$left.Controls.Add($lblSrcProv)

$cbSrcProv = New-Object System.Windows.Forms.ComboBox
$cbSrcProv.Location = "150,45"
$cbSrcProv.Width = 350
$cbSrcProv.Items.AddRange($sourceProviders)
$cbSrcProv.SelectedIndex = 0
$toolTip.SetToolTip($cbSrcProv, "Provider for the -source argument.")
$left.Controls.Add($cbSrcProv)

# Source main value
$lblSrcMain = New-Object System.Windows.Forms.Label
$lblSrcMain.Text = $providerMainValueLabel[$cbSrcProv.SelectedItem]
$lblSrcMain.Location = "10,90"
$left.Controls.Add($lblSrcMain)

$srcInputPanel = New-Object System.Windows.Forms.Panel
$srcInputPanel.Location = "150,85"
$srcInputPanel.Size = "360,30"
$left.Controls.Add($srcInputPanel)

$txtSrcMain = New-Object System.Windows.Forms.TextBox
$txtSrcMain.Location = "0,0"
$txtSrcMain.Width = 350
$srcInputPanel.Controls.Add($txtSrcMain)

$btnSrcBrowse = New-Object System.Windows.Forms.Button
$btnSrcBrowse.Text = "Browse..."
$btnSrcBrowse.Location = "270,0"
$btnSrcBrowse.Size = "80,23"
$btnSrcBrowse.Visible = $false
$srcInputPanel.Controls.Add($btnSrcBrowse)

$cbSrcSites = New-Object System.Windows.Forms.ComboBox
$cbSrcSites.Location = "0,0"
$cbSrcSites.Width = 350
$cbSrcSites.DropDownStyle = "DropDownList"
$cbSrcSites.Visible = $false
$srcInputPanel.Controls.Add($cbSrcSites)

# Update label when provider changes
$cbSrcProv.Add_SelectedIndexChanged({
        $lblSrcMain.Text = $providerMainValueLabel[$cbSrcProv.SelectedItem]
        Set-ProviderMode -Side "Source" -Provider $cbSrcProv.SelectedItem
    })

# ===============================================================
# SOURCE CONNECTION ATTRIBUTES
# ===============================================================

$lblSrcIP = New-Object System.Windows.Forms.Label
$lblSrcIP.Text = "computerName (IP only):"
$lblSrcIP.Location = "10,130"
$left.Controls.Add($lblSrcIP)

$txtSrcIP = New-Object System.Windows.Forms.TextBox
$txtSrcIP.Location = "150,125"
$txtSrcIP.Width = 350
$toolTip.SetToolTip($txtSrcIP, "computerName for the source (IP preferred).")
$left.Controls.Add($txtSrcIP)

$lblSrcUser = New-Object System.Windows.Forms.Label
$lblSrcUser.Text = "userName:"
$lblSrcUser.Location = "10,170"
$left.Controls.Add($lblSrcUser)

$txtSrcUser = New-Object System.Windows.Forms.TextBox
$txtSrcUser.Location = "150,165"
$txtSrcUser.Width = 350
$toolTip.SetToolTip($txtSrcUser, "userName attribute for the source provider.")
$left.Controls.Add($txtSrcUser)

$lblSrcPass = New-Object System.Windows.Forms.Label
$lblSrcPass.Text = "password:"
$lblSrcPass.Location = "10,210"
$left.Controls.Add($lblSrcPass)

$txtSrcPass = New-Object System.Windows.Forms.TextBox
$txtSrcPass.Location = "150,205"
$txtSrcPass.Width = 350
$txtSrcPass.UseSystemPasswordChar = $true
$toolTip.SetToolTip($txtSrcPass, "password attribute for the source provider.")
$left.Controls.Add($txtSrcPass)

$lblSrcAuth = New-Object System.Windows.Forms.Label
$lblSrcAuth.Text = "authType:"
$lblSrcAuth.Location = "10,250"
$left.Controls.Add($lblSrcAuth)

$cbSrcAuth = New-Object System.Windows.Forms.ComboBox
$cbSrcAuth.Location = "150,245"
$cbSrcAuth.Width = 350
$cbSrcAuth.Items.AddRange(@("Basic", "NTLM", "Negotiate", "None"))
$cbSrcAuth.SelectedIndex = -1
$toolTip.SetToolTip($cbSrcAuth, "authType attribute for the source provider.")
$left.Controls.Add($cbSrcAuth)

# Flags
$lblFlags = New-Object System.Windows.Forms.Label
$lblFlags.Text = "Global Flags:"
$lblFlags.Location = "10,300"
$left.Controls.Add($lblFlags)

$lstFlags = New-Object System.Windows.Forms.CheckedListBox
$lstFlags.Location = "10,325"
$lstFlags.Size = "250,150"
$lstFlags.Items.AddRange($flags)
$left.Controls.Add($lstFlags)

# Rules
$lblRules = New-Object System.Windows.Forms.Label
$lblRules.Text = "Rules:"
$lblRules.Location = "300,300"
$left.Controls.Add($lblRules)

$lstRules = New-Object System.Windows.Forms.CheckedListBox
$lstRules.Location = "300,325"
$lstRules.Size = "250,150"
$lstRules.Items.AddRange($rules)
$left.Controls.Add($lstRules)

# Enable Links
$lblELinks = New-Object System.Windows.Forms.Label
$lblELinks.Text = "Enable Links:"
$lblELinks.Location = "10,490"
$left.Controls.Add($lblELinks)

$lstELinks = New-Object System.Windows.Forms.CheckedListBox
$lstELinks.Location = "10,515"
$lstELinks.Size = "250,150"
$lstELinks.Items.AddRange($enableLinks)
$left.Controls.Add($lstELinks)

# Disable Links
$lblDLinks = New-Object System.Windows.Forms.Label
$lblDLinks.Text = "Disable Links:"
$lblDLinks.Location = "300,490"
$left.Controls.Add($lblDLinks)

$lstDLinks = New-Object System.Windows.Forms.CheckedListBox
$lstDLinks.Location = "300,515"
$lstDLinks.Size = "250,150"
$lstDLinks.Items.AddRange($disableLinks)
$left.Controls.Add($lstDLinks)

# ===============================================================
# RIGHT PANEL (DESTINATION)
# ===============================================================

$right = New-Object System.Windows.Forms.Panel
$right.Location = "580,160"
$right.Size = "560,720"
$right.BorderStyle = "FixedSingle"
$form.Controls.Add($right)

$lblDest = New-Object System.Windows.Forms.Label
$lblDest.Text = "DESTINATION CONFIGURATION"
$lblDest.Font = "Arial,10,style=Bold"
$lblDest.Location = "10,10"
$right.Controls.Add($lblDest)

# Destination provider
$lblDstProv = New-Object System.Windows.Forms.Label
$lblDstProv.Text = "Destination Provider:"
$lblDstProv.Location = "10,50"
$right.Controls.Add($lblDstProv)

$cbDstProv = New-Object System.Windows.Forms.ComboBox
$cbDstProv.Location = "175,45"
$cbDstProv.Width = 350
$cbDstProv.Items.AddRange($destProviders)
$cbDstProv.SelectedIndex = 0
$toolTip.SetToolTip($cbDstProv, "Provider for the -dest argument.")
$right.Controls.Add($cbDstProv)

# Destination main value
$lblDstMain = New-Object System.Windows.Forms.Label
$lblDstMain.Text = $providerMainValueLabel[$cbDstProv.SelectedItem]
$lblDstMain.Location = "10,90"
$right.Controls.Add($lblDstMain)

$dstInputPanel = New-Object System.Windows.Forms.Panel
$dstInputPanel.Location = "175,85"
$dstInputPanel.Size = "360,30"
$right.Controls.Add($dstInputPanel)

$txtDstMain = New-Object System.Windows.Forms.TextBox
$txtDstMain.Location = "0,0"
$txtDstMain.Width = 350
$dstInputPanel.Controls.Add($txtDstMain)

$btnDstBrowse = New-Object System.Windows.Forms.Button
$btnDstBrowse.Text = "Browse..."
$btnDstBrowse.Location = "270,0"
$btnDstBrowse.Size = "80,23"
$btnDstBrowse.Visible = $false
$dstInputPanel.Controls.Add($btnDstBrowse)

$cbDstSites = New-Object System.Windows.Forms.ComboBox
$cbDstSites.Location = "0,0"
$cbDstSites.Width = 350
$cbDstSites.DropDownStyle = "DropDownList"
$cbDstSites.Visible = $false
$dstInputPanel.Controls.Add($cbDstSites)

$cbDstProv.Add_SelectedIndexChanged({
        $lblDstMain.Text = $providerMainValueLabel[$cbDstProv.SelectedItem]
        Set-ProviderMode -Side "Destination" -Provider $cbDstProv.SelectedItem
    })

# ===============================================================
# DESTINATION CONNECTION ATTRIBUTES
# ===============================================================

$lblDstIP = New-Object System.Windows.Forms.Label
$lblDstIP.Text = "computerName (IP only):"
$lblDstIP.Location = "10,130"
$right.Controls.Add($lblDstIP)

$txtDstIP = New-Object System.Windows.Forms.TextBox
$txtDstIP.Location = "175,125"
$txtDstIP.Width = 350
$toolTip.SetToolTip($txtDstIP, "computerName for the destination (IP preferred).")
$right.Controls.Add($txtDstIP)

$lblDstUser = New-Object System.Windows.Forms.Label
$lblDstUser.Text = "userName:"
$lblDstUser.Location = "10,170"
$right.Controls.Add($lblDstUser)

$txtDstUser = New-Object System.Windows.Forms.TextBox
$txtDstUser.Location = "175,165"
$txtDstUser.Width = 350
$toolTip.SetToolTip($txtDstUser, "userName attribute for the destination provider.")
$right.Controls.Add($txtDstUser)

$lblDstPass = New-Object System.Windows.Forms.Label
$lblDstPass.Text = "password:"
$lblDstPass.Location = "10,210"
$right.Controls.Add($lblDstPass)

$txtDstPass = New-Object System.Windows.Forms.TextBox
$txtDstPass.Location = "175,205"
$txtDstPass.Width = 350
$txtDstPass.UseSystemPasswordChar = $true
$toolTip.SetToolTip($txtDstPass, "password attribute for the destination provider.")
$right.Controls.Add($txtDstPass)

$lblDstAuth = New-Object System.Windows.Forms.Label
$lblDstAuth.Text = "authType:"
$lblDstAuth.Location = "10,250"
$right.Controls.Add($lblDstAuth)

$cbDstAuth = New-Object System.Windows.Forms.ComboBox
$cbDstAuth.Location = "175,245"
$cbDstAuth.Width = 350
$cbDstAuth.Items.AddRange(@("Basic", "NTLM", "Negotiate", "None"))
$cbDstAuth.SelectedIndex = -1
$toolTip.SetToolTip($cbDstAuth, "authType attribute for the destination provider.")
$right.Controls.Add($cbDstAuth)

$sideControls = @{
    "Source" = @{
        Provider = $cbSrcProv
        Auth     = $cbSrcAuth
        IP       = $txtSrcIP
        User     = $txtSrcUser
        Pass     = $txtSrcPass
    }
    "Destination" = @{
        Provider = $cbDstProv
        Auth     = $cbDstAuth
        IP       = $txtDstIP
        User     = $txtDstUser
        Pass     = $txtDstPass
    }
}

$providerUiStates = @{
    "Source" = [ordered]@{
        TextBox      = $txtSrcMain
        SiteCombo    = $cbSrcSites
        BrowseButton = $btnSrcBrowse
        ProviderList = $cbSrcProv
        CurrentMode  = "Text"
        BrowseMode   = $null
        FileFilter   = $null
    }
    "Destination" = [ordered]@{
        TextBox      = $txtDstMain
        SiteCombo    = $cbDstSites
        BrowseButton = $btnDstBrowse
        ProviderList = $cbDstProv
        CurrentMode  = "Text"
        BrowseMode   = $null
        FileFilter   = $null
    }
}

# Thin wrappers to keep the main script readable
function Set-ProviderMode {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [string]$Provider
    )
    Update-ProviderInputMode -Side $Side -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions -Provider $Provider
}

function Get-ProviderValue {
    param([ValidateSet("Source", "Destination")] [string]$Side)
    return Get-ProviderMainValue -Side $Side -ProviderUiStates $providerUiStates
}

function Update-SiteComboLocal {
    param([ValidateSet("Source", "Destination")] [string]$Side)
    Update-SiteCombo -Side $Side -ProviderUiStates $providerUiStates
}

function Update-AllSiteCombosLocal {
    Update-AllSiteCombos -ProviderUiStates $providerUiStates
}

function Get-SideConfigurationLocal {
    param([ValidateSet("Source", "Destination")] [string]$Side)
    return Get-SideConfiguration -Side $Side -SideControls $sideControls -ProviderUiStates $providerUiStates
}

function Set-SideConfigurationLocal {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$Config
    )
    Set-SideConfiguration -Side $Side -Config $Config -SideControls $sideControls -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions
}

function Copy-SideConfigurationLocal {
    param(
        [ValidateSet("Source", "Destination")] [string]$From,
        [ValidateSet("Source", "Destination")] [string]$To
    )
    Copy-SideConfiguration -From $From -To $To -SideControls $sideControls -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions
    Update-Command
}

function Switch-SideConfigurationLocal {
    Switch-SideConfiguration -SideControls $sideControls -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions
    Update-Command
}

function Clear-SideConfigurationLocal {
    param([ValidateSet("Source", "Destination")] [string]$Side)
    Clear-SideConfiguration -Side $Side -SideControls $sideControls -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions
}

function Clear-AllInputs {
    foreach ($side in @("Source", "Destination")) {
        Clear-SideConfigurationLocal -Side $side
    }

    $cbVerb.SelectedIndex = 0
    Reset-CheckedListBox $lstFlags
    Reset-CheckedListBox $lstRules
    Reset-CheckedListBox $lstELinks
    Reset-CheckedListBox $lstDLinks

    $logBox.Clear()
    $cmdBox.Clear()
    Update-Command
}

function Save-GuiState {
    param([string]$Path)
    Save-GuiStateToFile -Path $Path -SideControls $sideControls -ProviderUiStates $providerUiStates -VerbCombo $cbVerb -FlagsList $lstFlags -RulesList $lstRules -EnableLinksList $lstELinks -DisableLinksList $lstDLinks
}

function Load-GuiState {
    param([string]$Path)
    Load-GuiStateFromFile -Path $Path -SideControls $sideControls -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions -VerbCombo $cbVerb -FlagsList $lstFlags -RulesList $lstRules -EnableLinksList $lstELinks -DisableLinksList $lstDLinks
    Update-Command
}

$btnSrcBrowse.Add_Click({
        Invoke-BrowseDialog -Side "Source" -ProviderUiStates $providerUiStates
    })
$btnDstBrowse.Add_Click({
        Invoke-BrowseDialog -Side "Destination" -ProviderUiStates $providerUiStates
    })

# ===============================================================
# COMMAND PREVIEW
# ===============================================================

$lblPreview = New-Object System.Windows.Forms.Label
$lblPreview.Text = "Command Preview"
$lblPreview.Location = "10,930"
$lblPreview.Font = "Arial,9,style=Bold"
$form.Controls.Add($lblPreview)

$cmdBox = New-Object System.Windows.Forms.TextBox
$cmdBox.Multiline = $true
$cmdBox.ScrollBars = "Vertical"
$cmdBox.Location = "10,950"
$cmdBox.Size = "1130,80"
$cmdBox.Font = "Consolas,10"
$cmdBox.ReadOnly = $true
$form.Controls.Add($cmdBox)

$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = "Activity Log"
$lblLog.Location = "10,1040"
$lblLog.Font = "Arial,9,style=Bold"
$form.Controls.Add($lblLog)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Location = "10,1050"
$logBox.Size = "1130,120"
$logBox.Font = "Consolas,9"
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)

# ===============================================================
# COMMAND BUILDER
# ===============================================================

function Get-MsDeployCommandString {
    param(
        [switch]$IncludePassword
    )

    $verb = $cbVerb.SelectedItem
    $srcProv = $cbSrcProv.SelectedItem
    $dstProv = $cbDstProv.SelectedItem

    if (-not $verb -or -not $srcProv -or -not $dstProv) {
        return ""
    }

    $srcValue = Get-ProviderValue -Side "Source"
    $src = if ($srcValue) { "-source:$srcProv=`"$srcValue`"" } else { "-source:$srcProv" }

    $dstValue = Get-ProviderValue -Side "Destination"
    $dest = if ($dstValue) { "-dest:$dstProv=`"$dstValue`"" } else { "-dest:$dstProv" }

    # Source attributes
    $srcAttributes = @()
    if ($txtSrcIP.Text.Trim()) {
        $srcAttributes += "computerName=`"$($txtSrcIP.Text.Trim())`""
    }
    if ($txtSrcUser.Text.Trim()) {
        $srcAttributes += "userName=`"$($txtSrcUser.Text.Trim())`""
    }
    if ($txtSrcPass.Text.Trim()) {
        $passwordValue = if ($IncludePassword) { $txtSrcPass.Text.Trim() } else { "<hidden>" }
        $srcAttributes += "password=`"$passwordValue`""
    }
    if ($cbSrcAuth.SelectedItem) {
        $srcAttributes += "authType=`"$($cbSrcAuth.SelectedItem)`""
    }

    if ($srcAttributes.Count -gt 0) {
        $src += "," + ($srcAttributes -join ",")
    }

    # Destination attributes
    $destAttributes = @()
    if ($txtDstIP.Text.Trim()) {
        $destAttributes += "computerName=`"$($txtDstIP.Text.Trim())`""
    }
    if ($txtDstUser.Text.Trim()) {
        $destAttributes += "userName=`"$($txtDstUser.Text.Trim())`""
    }
    if ($txtDstPass.Text.Trim()) {
        $passwordValue = if ($IncludePassword) { $txtDstPass.Text.Trim() } else { "<hidden>" }
        $destAttributes += "password=`"$passwordValue`""
    }
    if ($cbDstAuth.SelectedItem) {
        $destAttributes += "authType=`"$($cbDstAuth.SelectedItem)`""
    }

    if ($destAttributes.Count -gt 0) {
        $dest += "," + ($destAttributes -join ",")
    }

    $extras = @()
    foreach ($f in $lstFlags.CheckedItems) { $extras += $f }
    foreach ($r in $lstRules.CheckedItems) { $extras += "-$r" }
    foreach ($l in $lstELinks.CheckedItems) { $extras += "-$l" }
    foreach ($l in $lstDLinks.CheckedItems) { $extras += "-$l" }

    $cmdParts = @(
        "`"$msDeployPath`"",
        "-verb:$verb",
        $src,
        $dest
    ) + $extras

    return $cmdParts -join " "
}

function Update-Command {
    $command = Get-MsDeployCommandString
    if ([string]::IsNullOrWhiteSpace($command)) {
        $cmdBox.Text = ""
        return
    }
    $cmdBox.Text = "cmd.exe /c $command"
}

function Write-LogLines {
    param(
        [string[]]$Lines
    )

    if (-not $Lines) {
        return
    }

    $logText = ($Lines -join [Environment]::NewLine) + [Environment]::NewLine
    $logBox.AppendText($logText)
}

function Invoke-MsDeployCommand {
    param(
        [switch]$DryRun
    )

    $command = Get-MsDeployCommandString -IncludePassword
    $displayCommand = Get-MsDeployCommandString

    if (-not $command) {
        [System.Windows.Forms.MessageBox]::Show("Build a command before executing.", "MSDeploy PowerShell GUI") | Out-Null
        return
    }

    if ($DryRun -and $command -notmatch "(^|\s)-whatIf($|\s)") {
        $command += " -whatIf"
        if ($displayCommand -notmatch "(^|\s)-whatIf($|\s)") {
            $displayCommand += " -whatIf"
        }
    }

    $timestamp = (Get-Date).ToString("u")
    $header = "[{0}] cmd.exe /c {1}" -f $timestamp, $displayCommand
    Add-Content -Path $logFile -Value $header
    Write-LogLines $header

    $output = & cmd.exe /c $command 2>&1 | Tee-Object -FilePath $logFile -Append

    if ($output) {
        Write-LogLines $output
    }
    else {
        Write-LogLines @("[{0}] Command completed with no output." -f $timestamp)
    }

    if ($LASTEXITCODE -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("msdeploy command completed successfully.`nLog: $logFile", "MSDeploy PowerShell GUI") | Out-Null
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("msdeploy command failed (exit code $LASTEXITCODE). Review $logFile for details.", "MSDeploy PowerShell GUI") | Out-Null
    }
}

# Update preview on change
foreach ($ctl in @($cbVerb, $cbSrcProv, $cbDstProv, $cbSrcAuth, $cbDstAuth, $cbSrcSites, $cbDstSites)) {
    # ComboBox controls support TextChanged and SelectedIndexChanged
    $ctl.Add_TextChanged({ Update-Command }) 2>$null
    $ctl.Add_SelectedIndexChanged({ Update-Command }) 2>$null
}

foreach ($ctl in @($txtSrcMain, $txtDstMain, $txtSrcIP, $txtSrcUser, $txtSrcPass, $txtDstIP, $txtDstUser, $txtDstPass)) {
    # TextBox controls only support TextChanged
    $ctl.Add_TextChanged({ Update-Command }) 2>$null
}

foreach ($ctl in @($lstFlags, $lstRules, $lstELinks, $lstDLinks)) {
    # CheckedListBox controls support TextChanged and ItemCheck
    $ctl.Add_TextChanged({ Update-Command }) 2>$null
    $ctl.Add_ItemCheck({ Start-Sleep -Milliseconds 100; Update-Command }) 2>$null
}

Set-ProviderMode -Side "Source" -Provider $cbSrcProv.SelectedItem
Set-ProviderMode -Side "Destination" -Provider $cbDstProv.SelectedItem

# ===============================================================
# RUN BUTTONS
# ===============================================================

$btnExecute = New-Object System.Windows.Forms.Button
$btnExecute.Text = "Execute"
$btnExecute.Location = "10,1185"
$btnExecute.Size = "120,30"
$btnExecute.Add_Click({
        Invoke-MsDeployCommand
    })
$toolTip.SetToolTip($btnExecute, "Execute the currently previewed msdeploy command.")
$form.Controls.Add($btnExecute)

$btnDry = New-Object System.Windows.Forms.Button
$btnDry.Text = "Dry Run (-whatIf)"
$btnDry.Location = "150,1185"
$btnDry.Size = "150,30"
$btnDry.Add_Click({
        Invoke-MsDeployCommand -DryRun
    })
$toolTip.SetToolTip($btnDry, "Append -whatIf to validate without making changes.")
$form.Controls.Add($btnDry)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy"
$btnCopy.Location = "320,1185"
$btnCopy.Size = "120,30"
$btnCopy.Add_Click({
        $command = $cmdBox.Text.Trim()
        if ($command) {
            [System.Windows.Forms.Clipboard]::SetText($command)
        }
    })
$toolTip.SetToolTip($btnCopy, "Copy the cmd.exe invocation for use elsewhere.")
$form.Controls.Add($btnCopy)

# ===============================================================
# SHOW FORM
# ===============================================================

$form.Add_Shown({ Update-Command })
$form.ShowDialog()
