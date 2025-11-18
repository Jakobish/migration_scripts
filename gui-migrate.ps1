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
    "-whatIf",
    "-allowUntrusted",
    "-verbose"
)

# ===============================================================
# CREATE MAIN FORM
# ===============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "MSDeploy PowerShell GUI"
$form.Size = New-Object System.Drawing.Size(1200, 1020)
$form.StartPosition = "CenterScreen"

# ===============================================================
# LEFT PANEL (SOURCE)
# ===============================================================

$left = New-Object System.Windows.Forms.Panel
$left.Location = "10,10"
$left.Size = "560,720"
$left.BorderStyle = "FixedSingle"
$form.Controls.Add($left)

$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Text = "SOURCE CONFIGURATION"
$lblSource.Font = "Arial,12,style=Bold"
$lblSource.Location = "10,10"
$left.Controls.Add($lblSource)

# Verb
$lblVerb = New-Object System.Windows.Forms.Label
$lblVerb.Text = "Verb:"
$lblVerb.Location = "10,50"
$left.Controls.Add($lblVerb)

$cbVerb = New-Object System.Windows.Forms.ComboBox
$cbVerb.Location = "150,45"
$cbVerb.Width = 350
$cbVerb.Items.AddRange($verbs)
$cbVerb.SelectedIndex = 0
$left.Controls.Add($cbVerb)

# Source provider
$lblSrcProv = New-Object System.Windows.Forms.Label
$lblSrcProv.Text = "Source Provider:"
$lblSrcProv.Location = "10,90"
$left.Controls.Add($lblSrcProv)

$cbSrcProv = New-Object System.Windows.Forms.ComboBox
$cbSrcProv.Location = "150,85"
$cbSrcProv.Width = 350
$cbSrcProv.Items.AddRange($sourceProviders)
$cbSrcProv.SelectedIndex = 0
$left.Controls.Add($cbSrcProv)

# Source main value
$lblSrcMain = New-Object System.Windows.Forms.Label
$lblSrcMain.Text = $providerMainValueLabel[$cbSrcProv.SelectedItem]
$lblSrcMain.Location = "10,130"
$left.Controls.Add($lblSrcMain)

$srcInputPanel = New-Object System.Windows.Forms.Panel
$srcInputPanel.Location = "150,125"
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
# RIGHT PANEL (DESTINATION)
# ===============================================================

$right = New-Object System.Windows.Forms.Panel
$right.Location = "580,10"
$right.Size = "560,720"
$right.BorderStyle = "FixedSingle"
$form.Controls.Add($right)

$lblDest = New-Object System.Windows.Forms.Label
$lblDest.Text = "DESTINATION CONFIGURATION"
$lblDest.Font = "Arial,12,style=Bold"
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
$right.Controls.Add($cbDstProv)

# Main provider argument
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

$btnSrcBrowse.Add_Click({
        Invoke-BrowseDialog -Side "Source"
    })
$btnDstBrowse.Add_Click({
        Invoke-BrowseDialog -Side "Destination"
    })

# Inline attributes (computerName, user, pass, authType)
$lblIP = New-Object System.Windows.Forms.Label
$lblIP.Text = "computerName (IP only):"
$lblIP.Location = "10,130"
$right.Controls.Add($lblIP)

$txtIP = New-Object System.Windows.Forms.TextBox
$txtIP.Location = "175,125"
$txtIP.Width = 350
$right.Controls.Add($txtIP)

$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "userName:"
$lblUser.Location = "10,170"
$right.Controls.Add($lblUser)

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Location = "175,165"
$txtUser.Width = 350
$right.Controls.Add($txtUser)

$lblPass = New-Object System.Windows.Forms.Label
$lblPass.Text = "password:"
$lblPass.Location = "10,210"
$right.Controls.Add($lblPass)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Location = "175,205"
$txtPass.Width = 350
$txtPass.UseSystemPasswordChar = $true
$right.Controls.Add($txtPass)

$lblAuth = New-Object System.Windows.Forms.Label
$lblAuth.Text = "authType:"
$lblAuth.Location = "10,250"
$right.Controls.Add($lblAuth)

$cbAuth = New-Object System.Windows.Forms.ComboBox
$cbAuth.Location = "175,245"
$cbAuth.Width = 350
$cbAuth.Items.AddRange(@("Basic", "NTLM", "Negotiate", "None"))
$cbAuth.SelectedIndex = -1
$right.Controls.Add($cbAuth)

# ===============================================================
# FLAGS / RULES / LINKS
# ===============================================================

# Flags
$lblFlags = New-Object System.Windows.Forms.Label
$lblFlags.Text = "Global Flags:"
$lblFlags.Location = "10,300"
$right.Controls.Add($lblFlags)

$lstFlags = New-Object System.Windows.Forms.CheckedListBox
$lstFlags.Location = "10,325"
$lstFlags.Size = "250,150"
$lstFlags.Items.AddRange($flags)
$right.Controls.Add($lstFlags)

# Rules
$lblRules = New-Object System.Windows.Forms.Label
$lblRules.Text = "Rules:"
$lblRules.Location = "300,300"
$right.Controls.Add($lblRules)

$lstRules = New-Object System.Windows.Forms.CheckedListBox
$lstRules.Location = "300,325"
$lstRules.Size = "250,150"
$lstRules.Items.AddRange($rules)
$right.Controls.Add($lstRules)

# Enable Links
$lblELinks = New-Object System.Windows.Forms.Label
$lblELinks.Text = "Enable Links:"
$lblELinks.Location = "10,490"
$right.Controls.Add($lblELinks)

$lstELinks = New-Object System.Windows.Forms.CheckedListBox
$lstELinks.Location = "10,515"
$lstELinks.Size = "250,150"
$lstELinks.Items.AddRange($enableLinks)
$right.Controls.Add($lstELinks)

# Disable Links
$lblDLinks = New-Object System.Windows.Forms.Label
$lblDLinks.Text = "Disable Links:"
$lblDLinks.Location = "300,490"
$right.Controls.Add($lblDLinks)

$lstDLinks = New-Object System.Windows.Forms.CheckedListBox
$lstDLinks.Location = "300,515"
$lstDLinks.Size = "250,150"
$lstDLinks.Items.AddRange($disableLinks)
$right.Controls.Add($lstDLinks)

# ===============================================================
# COMMAND PREVIEW
# ===============================================================

$cmdBox = New-Object System.Windows.Forms.TextBox
$cmdBox.Multiline = $true
$cmdBox.ScrollBars = "Vertical"
$cmdBox.Location = "10,740"
$cmdBox.Size = "1130,80"
$cmdBox.Font = "Consolas,10"
$cmdBox.ReadOnly = $true
$form.Controls.Add($cmdBox)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Location = "10,830"
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

    $destAttributes = @()

    if ($txtIP.Text.Trim()) {
        $destAttributes += "computerName=`"$($txtIP.Text.Trim())`""
    }
    if ($txtUser.Text.Trim()) {
        $destAttributes += "userName=`"$($txtUser.Text.Trim())`""
    }
    if ($txtPass.Text.Trim()) {
        $passwordValue = if ($IncludePassword) { $txtPass.Text.Trim() } else { "<hidden>" }
        $destAttributes += "password=`"$passwordValue`""
    }
    if ($cbAuth.SelectedItem) {
        $destAttributes += "authType=`"$($cbAuth.SelectedItem)`""
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
foreach ($ctl in @($cbVerb, $cbSrcProv, $cbDstProv, $cbAuth, $cbSrcSites, $cbDstSites)) {
    # ComboBox controls support TextChanged and SelectedIndexChanged
    $ctl.Add_TextChanged({ Update-Command }) 2>$null
    $ctl.Add_SelectedIndexChanged({ Update-Command }) 2>$null
}

foreach ($ctl in @($txtSrcMain, $txtDstMain, $txtIP, $txtUser, $txtPass)) {
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
$btnExecute.Location = "10,965"
$btnExecute.Size = "120,30"
    $btnExecute.Add_Click({
        Invoke-MsDeployCommand
    })
$form.Controls.Add($btnExecute)

$btnDry = New-Object System.Windows.Forms.Button
$btnDry.Text = "Dry Run (-whatIf)"
$btnDry.Location = "150,965"
$btnDry.Size = "150,30"
    $btnDry.Add_Click({
        Invoke-MsDeployCommand -DryRun
    })
$form.Controls.Add($btnDry)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy"
$btnCopy.Location = "320,965"
$btnCopy.Size = "120,30"
$btnCopy.Add_Click({
        $command = $cmdBox.Text.Trim()
        if ($command) {
            [System.Windows.Forms.Clipboard]::SetText($command)
        }
    })
$form.Controls.Add($btnCopy)

# ===============================================================
# SHOW FORM
# ===============================================================

$form.Add_Shown({ Update-Command })
$form.ShowDialog()
