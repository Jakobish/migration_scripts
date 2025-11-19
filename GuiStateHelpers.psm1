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

function Swap-SideConfiguration {
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

function Get-GuiState {
    param(
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates,
        [System.Windows.Forms.ComboBox]$VerbCombo,
        [System.Windows.Forms.CheckedListBox]$FlagsList,
        [System.Windows.Forms.CheckedListBox]$RulesList,
        [System.Windows.Forms.CheckedListBox]$EnableLinksList,
        [System.Windows.Forms.CheckedListBox]$DisableLinksList
    )

    return [ordered]@{
        Verb         = $VerbCombo.SelectedItem
        Source       = Get-SideConfiguration -Side "Source" -SideControls $SideControls -ProviderUiStates $ProviderUiStates
        Destination  = Get-SideConfiguration -Side "Destination" -SideControls $SideControls -ProviderUiStates $ProviderUiStates
        Flags        = Get-CheckedItems $FlagsList
        Rules        = Get-CheckedItems $RulesList
        EnableLinks  = Get-CheckedItems $EnableLinksList
        DisableLinks = Get-CheckedItems $DisableLinksList
    }
}

function Set-GuiState {
    param(
        [object]$State,
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates,
        [hashtable]$ProviderInputOptions,
        [System.Windows.Forms.ComboBox]$VerbCombo,
        [System.Windows.Forms.CheckedListBox]$FlagsList,
        [System.Windows.Forms.CheckedListBox]$RulesList,
        [System.Windows.Forms.CheckedListBox]$EnableLinksList,
        [System.Windows.Forms.CheckedListBox]$DisableLinksList
    )
    if (-not $State) { return }

    if ($State.Verb -and $VerbCombo.Items.Contains($State.Verb)) {
        $VerbCombo.SelectedItem = $State.Verb
    }
    elseif ($VerbCombo.Items.Count -gt 0) {
        $VerbCombo.SelectedIndex = 0
    }

    if ($State.Source) {
        Set-SideConfiguration -Side "Source" -Config $State.Source -SideControls $SideControls -ProviderUiStates $ProviderUiStates -ProviderInputOptions $ProviderInputOptions
    }

    if ($State.Destination) {
        Set-SideConfiguration -Side "Destination" -Config $State.Destination -SideControls $SideControls -ProviderUiStates $ProviderUiStates -ProviderInputOptions $ProviderInputOptions
    }

    Set-CheckedItems -List $FlagsList -Items $State.Flags
    Set-CheckedItems -List $RulesList -Items $State.Rules
    Set-CheckedItems -List $EnableLinksList -Items $State.EnableLinks
    Set-CheckedItems -List $DisableLinksList -Items $State.DisableLinks
}

function Save-GuiStateToFile {
    param(
        [string]$Path,
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates,
        [System.Windows.Forms.ComboBox]$VerbCombo,
        [System.Windows.Forms.CheckedListBox]$FlagsList,
        [System.Windows.Forms.CheckedListBox]$RulesList,
        [System.Windows.Forms.CheckedListBox]$EnableLinksList,
        [System.Windows.Forms.CheckedListBox]$DisableLinksList
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    try {
        $state = Get-GuiState -SideControls $SideControls -ProviderUiStates $ProviderUiStates -VerbCombo $VerbCombo -FlagsList $FlagsList -RulesList $RulesList -EnableLinksList $EnableLinksList -DisableLinksList $DisableLinksList
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

function Load-GuiStateFromFile {
    param(
        [string]$Path,
        [hashtable]$SideControls,
        [hashtable]$ProviderUiStates,
        [hashtable]$ProviderInputOptions,
        [System.Windows.Forms.ComboBox]$VerbCombo,
        [System.Windows.Forms.CheckedListBox]$FlagsList,
        [System.Windows.Forms.CheckedListBox]$RulesList,
        [System.Windows.Forms.CheckedListBox]$EnableLinksList,
        [System.Windows.Forms.CheckedListBox]$DisableLinksList
    )

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

        Set-GuiState -State $state -SideControls $SideControls -ProviderUiStates $ProviderUiStates -ProviderInputOptions $ProviderInputOptions -VerbCombo $VerbCombo -FlagsList $FlagsList -RulesList $RulesList -EnableLinksList $EnableLinksList -DisableLinksList $DisableLinksList
        [System.Windows.Forms.MessageBox]::Show("Loaded GUI state from $Path.", "MSDeploy PowerShell GUI") | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to load state: $($_.Exception.Message)", "MSDeploy PowerShell GUI") | Out-Null
    }
}
