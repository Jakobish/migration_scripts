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

function Get-RemoteIisSiteNames {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Password is already handled as plain text in GUI TextBox controls')]
    param(
        [string]$ComputerName,
        [string]$UserName,
        [string]$Password,
        [string]$AuthType = "NTLM"
    )
    
    # If no computer name specified, get local sites
    if (-not $ComputerName -or $ComputerName.Trim() -eq "") {
        return Get-IisSiteNames
    }
    
    try {
        # Build credential if username provided
        $credential = $null
        if ($UserName -and $Password) {
            $securePass = ConvertTo-SecureString $Password -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($UserName, $securePass)
        }
        
        # Create session options to handle non-domain scenarios
        $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        
        # Use PowerShell remoting to get sites from remote server
        $scriptBlock = {
            try {
                Import-Module WebAdministration -ErrorAction Stop
                return (Get-ChildItem IIS:\Sites | Select-Object -ExpandProperty Name)
            }
            catch {
                return @()
            }
        }
        
        $params = @{
            ComputerName  = $ComputerName
            ScriptBlock   = $scriptBlock
            SessionOption = $sessionOption
        }
        
        if ($credential) {
            $params.Credential = $credential
        }
        
        $sites = Invoke-Command @params -ErrorAction Stop
        return $sites
    }
    catch {
        $errorMsg = $_.Exception.Message
        
        # Provide helpful error messages based on common issues
        if ($errorMsg -match "TrustedHosts") {
            Write-Warning "Failed to connect to $ComputerName - TrustedHosts configuration required.`n" +
            "Run this command as Administrator on the local machine:`n" +
            "Set-Item WSMan:\localhost\Client\TrustedHosts -Value '$ComputerName' -Force"
        }
        elseif ($errorMsg -match "Access is denied") {
            Write-Warning "Failed to connect to $ComputerName - Access denied. Check credentials and permissions."
        }
        elseif ($errorMsg -match "WinRM") {
            Write-Warning "Failed to connect to $ComputerName - WinRM issue.`n" +
            "Ensure WinRM is enabled on the remote server: Enable-PSRemoting -Force"
        }
        else {
            Write-Warning "Failed to retrieve sites from $ComputerName : $errorMsg"
        }
        
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Password is already handled as plain text in GUI TextBox controls')]
    param(
        [hashtable]$State,
        [string]$ComputerName = "",
        [string]$UserName = "",
        [string]$Password = "",
        [string]$AuthType = "NTLM"
    )

    if (-not $State) { return }

    $combo = $State.SiteCombo
    $combo.Items.Clear()
    
    # Get sites from remote server if connection details provided, otherwise local
    $sites = Get-RemoteIisSiteNames -ComputerName $ComputerName -UserName $UserName -Password $Password -AuthType $AuthType
    
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
        [hashtable]$ProviderUiStates,
        [hashtable]$SideControls
    )

    $state = $ProviderUiStates[$Side]
    if (-not $state -or $state.CurrentMode -ne "Site") { return }
    
    # Get connection details from the controls
    $controls = $SideControls[$Side]
    $computerName = if ($controls.IP) { $controls.IP.Text } else { "" }
    $userName = if ($controls.User) { $controls.User.Text } else { "" }
    $password = if ($controls.Pass) { $controls.Pass.Text } else { "" }
    $authType = if ($controls.Auth) { $controls.Auth.Text } else { "NTLM" }

    $currentValue = $state.SiteCombo.Text
    if (Initialize-SiteComboBox -State $state -ComputerName $computerName -UserName $userName -Password $password -AuthType $authType) {
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
    param(
        [hashtable]$ProviderUiStates,
        [hashtable]$SideControls
    )
    Initialize-SiteCombo -Side "Source" -ProviderUiStates $ProviderUiStates -SideControls $SideControls
    Initialize-SiteCombo -Side "Destination" -ProviderUiStates $ProviderUiStates -SideControls $SideControls
}
