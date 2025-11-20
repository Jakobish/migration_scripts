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
    if (-not (Test-Path IIS:\)) { return @() }
    try {
        return (Get-ChildItem IIS:\Sites | Select-Object -ExpandProperty Name)
    }
    catch {
        return @()
    }
}

function New-ActionButton {
    param(
        [System.Windows.Forms.ToolTip]$ToolTip,
        [string]$Text,
        [string]$TooltipText
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Width = 300
    $btn.Height = 25
    if ($ToolTip -and $TooltipText) {
        $ToolTip.SetToolTip($btn, $TooltipText)
    }
    return $btn
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
    $state.RefreshButton.Visible = $false
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
            $state.SiteCombo.Width = 260
            $state.SiteCombo.Visible = $true
            $state.SiteCombo.Enabled = $true
            $state.RefreshButton.Visible = $true
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

function Initialize-SiteCombo {
    param(
        [ValidateSet("Source", "Destination")] [string]$Side,
        [hashtable]$ProviderUiStates
    )

    $state = $ProviderUiStates[$Side]
    if (-not $state -or $state.CurrentMode -ne "Site") { return }

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

function Initialize-AllSiteCombos {
    param([hashtable]$ProviderUiStates)
    Initialize-SiteCombo -Side "Source" -ProviderUiStates $ProviderUiStates
    Initialize-SiteCombo -Side "Destination" -ProviderUiStates $ProviderUiStates
}
