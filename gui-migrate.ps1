#Requires -RunAsAdministrator
Import-Module WebAdministration
Import-Module (Join-Path $PSScriptRoot "MigrationHelper.psm1")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-FatalMessage {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show($Message, "MSDeploy PowerShell GUI") | Out-Null
}

try {
    Import-Module WebAdministration -ErrorAction Stop
}
catch {
    Show-FatalMessage "Unable to load WebAdministration module. Install IIS management tools before running this GUI."
    return
}

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
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

$btnCopySrcToDst = New-ActionButton -Text "Copy Source → Destination" -TooltipText "Mirror all fields from the left side to the right side."
$btnCopyDstToSrc = New-ActionButton -Text "Copy Destination → Source" -TooltipText "Mirror all fields from the right side to the left side."
$btnSwapSides = New-ActionButton -Text "Swap Source & Destination" -TooltipText "Exchange both sides so you can easily reverse a migration."
$btnRefreshSites = New-ActionButton -Text "Refresh IIS Site Lists" -TooltipText "Reload local IIS site names for both provider pickers."
$btnClearAll = New-ActionButton -Text "Clear Everything" -TooltipText "Reset all inputs, lists, and preview text."
$btnSaveState = New-ActionButton -Text "Save Layout (JSON/XML)" -TooltipText "Persist the current inputs to a JSON or XML file."
$btnLoadState = New-ActionButton -Text "Load Layout (JSON/XML)" -TooltipText "Load inputs from a previously saved JSON or XML file."

$actionPanel.Controls.Add($btnCopySrcToDst)
$actionPanel.Controls.Add($btnCopyDstToSrc)
$actionPanel.Controls.Add($btnSwapSides)
$actionPanel.Controls.Add($btnRefreshSites)
$actionPanel.Controls.Add($btnClearAll)
$actionPanel.Controls.Add($btnSaveState)
$actionPanel.Controls.Add($btnLoadState)

$btnCopySrcToDst.Add_Click({ Copy-SideConfiguration -From "Source" -To "Destination" })
$btnCopyDstToSrc.Add_Click({ Copy-SideConfiguration -From "Destination" -To "Source" })
$btnSwapSides.Add_Click({ Switch-SideConfiguration })
$btnRefreshSites.Add_Click({ Initialize-AllSiteCombos })
$btnClearAll.Add_Click({ Clear-AllInputs })
$btnSaveState.Add_Click({
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Filter = "JSON files (*.json)|*.json|XML files (*.xml)|*.xml|All files (*.*)|*.*"
        $dialog.DefaultExt = "json"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Save-GuiStateToFile -Path $dialog.FileName
        }
    })
$btnLoadState.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "JSON files (*.json)|*.json|XML files (*.xml)|*.xml|All files (*.*)|*.*"
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Read-GuiStateFromFile -Path $dialog.FileName
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
        Update-ProviderInputMode -Side "Source" -Provider $cbSrcProv.SelectedItem
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
        Update-ProviderInputMode -Side "Destination" -Provider $cbDstProv.SelectedItem
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

function Set-TextInputLayout {
    param(
        [string]$Side,
        [bool]$ShowBrowseButton
    )

    $state = $providerUiStates[$Side]
    if (-not $state) { return }

    if ($ShowBrowseButton) {
        $state.TextBox.Width = 260
        $state.BrowseButton.Location = "270,0"
    }
    else {
        $state.TextBox.Width = 350
    }

    $state.BrowseButton.Visible = $ShowBrowseButton
    $state.TextBox.Visible = $true
    $state.SiteCombo.Visible = $false
}

function Initialize-SiteComboBox {
    param(
        [string]$Side
    )

    $state = $providerUiStates[$Side]
    if (-not $state) { return }

    $combo = $state.SiteCombo
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
        [string]$Provider
    )

    $state = $providerUiStates[$Side]
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

    $options = $providerInputOptions[$Provider]
    $mode = if ($options) { $options.Mode } else { "Text" }
    $state.CurrentMode = $mode

    switch ($mode) {
        "Site" {
            if (Initialize-SiteComboBox -Side $Side) {
                $state.SiteCombo.Visible = $true
                $state.SiteCombo.Enabled = $true
                break
            }
            else {
                Set-TextInputLayout -Side $Side -ShowBrowseButton $false
                $state.CurrentMode = "Text"
            }
        }
        "File" {
            Set-TextInputLayout -Side $Side -ShowBrowseButton $true
            $state.BrowseMode = "File"
            $state.FileFilter = if ($options.Filter) { $options.Filter } else { "All Files (*.*)|*.*" }
        }
        "Folder" {
            Set-TextInputLayout -Side $Side -ShowBrowseButton $true
            $state.BrowseMode = "Folder"
        }
        default {
            Set-TextInputLayout -Side $Side -ShowBrowseButton $false
        }
    }
}

function Invoke-BrowseDialog {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side
    )

    $state = $providerUiStates[$Side]
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
        [ValidateSet("Source", "Destination")] [string]$Side
    )

    $state = $providerUiStates[$Side]
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

function Get-CheckedItems {
    param([System.Windows.Forms.CheckedListBox]$List)
    if (-not $List) { return @() }
    return @($List.CheckedItems | ForEach-Object { [string]$_ })
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

function Get-GuiState {
    return [ordered]@{
        Verb         = $cbVerb.SelectedItem
        Source       = Get-SideConfiguration -Side "Source"
        Destination  = Get-SideConfiguration -Side "Destination"
        Flags        = Get-CheckedItems $lstFlags
        Rules        = Get-CheckedItems $lstRules
        EnableLinks  = Get-CheckedItems $lstELinks
        DisableLinks = Get-CheckedItems $lstDLinks
    }
}

function Set-GuiState {
    param([object]$State)
    if (-not $State) { return }

    if ($State.Verb -and $cbVerb.Items.Contains($State.Verb)) {
        $cbVerb.SelectedItem = $State.Verb
    }
    elseif ($cbVerb.Items.Count -gt 0) {
        $cbVerb.SelectedIndex = 0
    }

    if ($State.Source) {
        Set-SideConfiguration -Side "Source" -Config $State.Source
    }

    if ($State.Destination) {
        Set-SideConfiguration -Side "Destination" -Config $State.Destination
    }

    Set-CheckedItems -List $lstFlags -Items $State.Flags
    Set-CheckedItems -List $lstRules -Items $State.Rules
    Set-CheckedItems -List $lstELinks -Items $State.EnableLinks
    Set-CheckedItems -List $lstDLinks -Items $State.DisableLinks

    Update-Command
}

function Save-GuiStateToFile {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    try {
        $state = Get-GuiState
        $extension = ([System.IO.Path]::GetExtension($Path)).ToLowerInvariant()

        switch ($extension) {
            ".json" {
                $state | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
            }
            ".xml" {
                $state | Export-Clixml -Path $Path
            }
            default {
                $state | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
            }
        }

        [System.Windows.Forms.MessageBox]::Show("Saved GUI state to $Path.", "MSDeploy PowerShell GUI") | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to save state: $($_.Exception.Message)", "MSDeploy PowerShell GUI") | Out-Null
    }
}

function Read-GuiStateFromFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        [System.Windows.Forms.MessageBox]::Show("File not found: $Path", "MSDeploy PowerShell GUI") | Out-Null
        return
    }

    try {
        $extension = ([System.IO.Path]::GetExtension($Path)).ToLowerInvariant()
        switch ($extension) {
            ".json" {
                $state = Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 8
            }
            ".xml" {
                $state = Import-Clixml -Path $Path
            }
            default {
                $state = Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 8
            }
        }

        if (-not $state) {
            [System.Windows.Forms.MessageBox]::Show("State file was empty or invalid.", "MSDeploy PowerShell GUI") | Out-Null
            return
        }

        Set-GuiState -State $state
        [System.Windows.Forms.MessageBox]::Show("Loaded GUI state from $Path.", "MSDeploy PowerShell GUI") | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to load state: $($_.Exception.Message)", "MSDeploy PowerShell GUI") | Out-Null
    }
}

function Get-SideConfiguration {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side
    )

    $map = $sideControls[$Side]
    if (-not $map) { return $null }

    $providerValue = if ($map.Provider.SelectedItem) { $map.Provider.SelectedItem } else { $map.Provider.Text }

    return [ordered]@{
        Provider = $providerValue
        Value    = Get-ProviderMainValue -Side $Side
        IP       = $map.IP.Text.Trim()
        User     = $map.User.Text.Trim()
        Pass     = $map.Pass.Text
        Auth     = $map.Auth.SelectedItem
    }
}

function Set-SideConfiguration {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$Config
    )

    if (-not $Config) { return }
    $map = $sideControls[$Side]
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
    Update-ProviderInputMode -Side $Side -Provider $providerArgument

    $state = $providerUiStates[$Side]
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
        [ValidateSet("Source", "Destination")] [string]$To
    )

    if ($From -eq $To) { return }
    $config = Get-SideConfiguration -Side $From
    Set-SideConfiguration -Side $To -Config $config
    Update-Command
}

function Switch-SideConfiguration {
    $sourceState = Get-SideConfiguration -Side "Source"
    $destState = Get-SideConfiguration -Side "Destination"
    Set-SideConfiguration -Side "Source" -Config $destState
    Set-SideConfiguration -Side "Destination" -Config $sourceState
    Update-Command
}

function Clear-SideConfiguration {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side
    )

    $map = $sideControls[$Side]
    if (-not $map) { return }

    if ($map.Provider.Items.Count -gt 0) {
        $map.Provider.SelectedIndex = 0
        Update-ProviderInputMode -Side $Side -Provider $map.Provider.SelectedItem
    }

    $state = $providerUiStates[$Side]
    $state.TextBox.Text = ""
    $state.SiteCombo.SelectedIndex = -1
    $state.SiteCombo.Text = ""

    $map.IP.Clear()
    $map.User.Clear()
    $map.Pass.Clear()
    $map.Auth.SelectedIndex = -1
}

function Clear-AllInputs {
    foreach ($side in @("Source", "Destination")) {
        Clear-SideConfiguration -Side $side
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

function Initialize-SiteCombo {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side
    )

    $state = $providerUiStates[$Side]
    if (-not $state -or $state.CurrentMode -ne "Site") { return }

    $currentValue = $state.SiteCombo.Text
    if (Initialize-SiteComboBox -Side $Side) {
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

function Initialize-AllSiteCombos {
    Initialize-SiteCombo -Side "Source"
    Initialize-SiteCombo -Side "Destination"
    Update-Command
}

$btnSrcBrowse.Add_Click({
        Invoke-BrowseDialog -Side "Source"
    })
$btnDstBrowse.Add_Click({
        Invoke-BrowseDialog -Side "Destination"
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

    $srcValue = Get-ProviderMainValue -Side "Source"
    $src = if ($srcValue) { "-source:$srcProv=`"$srcValue`"" } else { "-source:$srcProv" }

    $dstValue = Get-ProviderMainValue -Side "Destination"
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

Update-ProviderInputMode -Side "Source" -Provider $cbSrcProv.SelectedItem
Update-ProviderInputMode -Side "Destination" -Provider $cbDstProv.SelectedItem

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
