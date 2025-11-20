
# ===============================================================
# UI HELPER FUNCTIONS
# ===============================================================

function New-ToolbarButton {
    param([string]$Text, [string]$TooltipText)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.AutoSize = $true
    $btn.Padding = New-Object System.Windows.Forms.Padding(5, 0, 5, 0)
    $btn.Height = 28
    $btn.FlatStyle = "System"
    if ($TooltipText) { $toolTip.SetToolTip($btn, $TooltipText) }
    return $btn
}

function New-SidePanel {
    param([string]$Title, [string]$Side, [string[]]$Providers)
    
    $grp = New-Object System.Windows.Forms.GroupBox
    $grp.Text = $Title
    $grp.Dock = "Fill"
    $grp.Padding = New-Object System.Windows.Forms.Padding(10)
    
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = "Fill"
    $layout.ColumnCount = 2
    $layout.RowCount = 7
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 100)))
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    
    # Helper to add row
    $addRow = {
        param($labelTxt, $control, $rowIdx)
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $labelTxt
        $lbl.AutoSize = $true
        $lbl.Anchor = "Left"
        $layout.Controls.Add($lbl, 0, $rowIdx)
        $layout.Controls.Add($control, 1, $rowIdx)
    }
    
    # 1. Provider
    $cbProv = New-Object System.Windows.Forms.ComboBox
    $cbProv.Dock = "Fill"
    $cbProv.DropDownStyle = "DropDownList"
    $cbProv.Items.AddRange($Providers)
    $cbProv.SelectedIndex = 0
    &$addRow "Provider:" $cbProv 0
    
    # 2. Main Value (Dynamic Panel)
    $inputPanel = New-Object System.Windows.Forms.Panel
    $inputPanel.Dock = "Fill"
    $inputPanel.Height = 30
    $inputPanel.Margin = New-Object System.Windows.Forms.Padding(0)
    
    $txtMain = New-Object System.Windows.Forms.TextBox
    $txtMain.Dock = "Fill"
    $inputPanel.Controls.Add($txtMain)
    
    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "..."
    $btnBrowse.Width = 30
    $btnBrowse.Dock = "Right"
    $btnBrowse.Visible = $false
    $inputPanel.Controls.Add($btnBrowse)
    
    $cbSites = New-Object System.Windows.Forms.ComboBox
    $cbSites.Dock = "Fill"
    $cbSites.DropDownStyle = "DropDownList"
    $cbSites.Visible = $false
    $inputPanel.Controls.Add($cbSites)
    
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "R"
    $btnRefresh.Width = 30
    $btnRefresh.Dock = "Right"
    $btnRefresh.Visible = $false
    $toolTip.SetToolTip($btnRefresh, "Refresh Sites")
    $inputPanel.Controls.Add($btnRefresh)
    
    $lblMain = New-Object System.Windows.Forms.Label
    $lblMain.Text = "Value:"
    $lblMain.AutoSize = $true
    $lblMain.Anchor = "Left"
    $layout.Controls.Add($lblMain, 0, 1)
    $layout.Controls.Add($inputPanel, 1, 1)
    
    # 3. Computer (IP)
    $txtIP = New-Object System.Windows.Forms.TextBox
    $txtIP.Dock = "Fill"
    &$addRow "Computer:" $txtIP 2
    
    # 4. User
    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Dock = "Fill"
    &$addRow "Username:" $txtUser 3
    
    # 5. Pass
    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Dock = "Fill"
    $txtPass.UseSystemPasswordChar = $true
    &$addRow "Password:" $txtPass 4
    
    # 6. AuthType
    $cbAuth = New-Object System.Windows.Forms.ComboBox
    $cbAuth.Dock = "Fill"
    $cbAuth.DropDownStyle = "DropDownList"
    $cbAuth.Items.AddRange(@("Basic", "NTLM", "Negotiate", "None"))
    &$addRow "AuthType:" $cbAuth 5
    
    $grp.Controls.Add($layout)
    
    return @{
        Group      = $grp
        Prov       = $cbProv
        MainLbl    = $lblMain
        TxtMain    = $txtMain
        BtnBrowse  = $btnBrowse
        CbSites    = $cbSites
        BtnRefresh = $btnRefresh
        TxtIP      = $txtIP
        TxtUser    = $txtUser
        TxtPass    = $txtPass
        CbAuth     = $cbAuth
    }
}

function New-CheckListTab {
    param($Title, $Items)
    $page = New-Object System.Windows.Forms.TabPage
    $page.Text = $Title
    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Dock = "Fill"
    $list.CheckOnClick = $true
    $list.Items.AddRange($Items)
    $page.Controls.Add($list)
    $tabControl.TabPages.Add($page)
    return $list
}

function Set-ProviderMode {
    param(
        [string]$Side,
        [string]$Provider
    )
    Update-ProviderInputMode -Side $Side -ProviderUiStates $providerUiStates -ProviderInputOptions $providerInputOptions -Provider $Provider
}

# ===============================================================
# CREATE MAIN FORM
# ===============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "MSDeploy PowerShell GUI"
$form.Size = New-Object System.Drawing.Size(1200, 900)
$form.StartPosition = "CenterScreen"
$form.Font = "Segoe UI, 9pt"

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.ShowAlways = $true

# Main Layout
$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.Dock = "Fill"
$mainLayout.ColumnCount = 1
$mainLayout.RowCount = 4
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80))) # Header
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40))) # Toolbar
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 60))) # Config & Tabs
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 40))) # Preview & Log
$form.Controls.Add($mainLayout)

# ---------------------------------------------------------------
# 1. HEADER
# ---------------------------------------------------------------
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = "Fill"
$headerPanel.BackColor = [System.Drawing.Color]::White
$headerPanel.Padding = New-Object System.Windows.Forms.Padding(10)
$mainLayout.Controls.Add($headerPanel, 0, 0)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Dual-Sided MSDeploy Command Builder"
$titleLabel.Font = "Segoe UI, 14pt, style=Bold"
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(10, 10)
$headerPanel.Controls.Add($titleLabel)

$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Text = "Build identical source/destination definitions. Use the toolbar to mirror configurations."
$infoLabel.Location = New-Object System.Drawing.Point(12, 40)
$infoLabel.AutoSize = $true
$headerPanel.Controls.Add($infoLabel)

# ---------------------------------------------------------------
# 2. TOOLBAR
# ---------------------------------------------------------------
$toolbarPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$toolbarPanel.Dock = "Fill"
$toolbarPanel.FlowDirection = "LeftToRight"
$toolbarPanel.Padding = New-Object System.Windows.Forms.Padding(5)
$mainLayout.Controls.Add($toolbarPanel, 0, 1)

$btnCopySrcToDst = New-ToolbarButton "Copy Src -> Dst" "Mirror Source to Destination"
$btnCopyDstToSrc = New-ToolbarButton "Copy Dst -> Src" "Mirror Destination to Source"
$btnRefreshSites = New-ToolbarButton "Refresh Sites" "Reload IIS Sites"
$btnClearAll = New-ToolbarButton "Clear All" "Reset all inputs"
$btnSaveState = New-ToolbarButton "Save Layout" "Save to JSON/XML"
$btnLoadState = New-ToolbarButton "Load Layout" "Load from JSON/XML"
$btnRemoteGui = New-ToolbarButton "Remote GUI" "Launch on remote server"

$toolbarPanel.Controls.AddRange(@($btnCopySrcToDst, $btnCopyDstToSrc, $btnRefreshSites, $btnClearAll, $btnSaveState, $btnLoadState, $btnRemoteGui))

# Event Handlers for Toolbar
$btnCopySrcToDst.Add_Click({ Copy-SideConfigurationLocal -From "Source" -To "Destination" })
$btnCopyDstToSrc.Add_Click({ Copy-SideConfigurationLocal -From "Destination" -To "Source" })
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
            Initialize-GuiState -Path $dialog.FileName
        }
    })
$btnRemoteGui.Add_Click({ Show-RemoteGuiDialog })

# ---------------------------------------------------------------
# 3. CONFIGURATION AREA (Split + Tabs)
# ---------------------------------------------------------------
$configSplit = New-Object System.Windows.Forms.SplitContainer
$configSplit.Dock = "Fill"
$configSplit.Orientation = "Vertical"
$configSplit.SplitterDistance = 800 # Give more space to config
$mainLayout.Controls.Add($configSplit, 0, 2)

# LEFT SIDE OF SPLIT: Source/Dest Config
$sidesLayout = New-Object System.Windows.Forms.TableLayoutPanel
$sidesLayout.Dock = "Fill"
$sidesLayout.ColumnCount = 2
$sidesLayout.RowCount = 1
$sidesLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$sidesLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$configSplit.Panel1.Controls.Add($sidesLayout)

# Create Source Panel
$srcControls = New-SidePanel "Source Configuration" "Source" $sourceProviders
$sidesLayout.Controls.Add($srcControls.Group, 0, 0)

# Create Destination Panel
$dstControls = New-SidePanel "Destination Configuration" "Destination" $destProviders
$sidesLayout.Controls.Add($dstControls.Group, 1, 0)

# Map controls to variables expected by logic
$cbSrcProv = $srcControls.Prov
$lblSrcMain = $srcControls.MainLbl
$txtSrcMain = $srcControls.TxtMain
$btnSrcBrowse = $srcControls.BtnBrowse
$cbSrcSites = $srcControls.CbSites
$btnSrcRefresh = $srcControls.BtnRefresh
$txtSrcIP = $srcControls.TxtIP
$txtSrcUser = $srcControls.TxtUser
$txtSrcPass = $srcControls.TxtPass
$cbSrcAuth = $srcControls.CbAuth

$cbDstProv = $dstControls.Prov
$lblDstMain = $dstControls.MainLbl
$txtDstMain = $dstControls.TxtMain
$btnDstBrowse = $dstControls.BtnBrowse
$cbDstSites = $dstControls.CbSites
$btnDstRefresh = $dstControls.BtnRefresh
$txtDstIP = $dstControls.TxtIP
$txtDstUser = $dstControls.TxtUser
$txtDstPass = $dstControls.TxtPass
$cbDstAuth = $dstControls.CbAuth

# RIGHT SIDE OF SPLIT: Settings Tabs
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = "Fill"
$configSplit.Panel2.Controls.Add($tabControl)

$lstFlags = New-CheckListTab "Global Flags" $flags
$lstRules = New-CheckListTab "Rules" $rules
$lstELinks = New-CheckListTab "Enable Links" $enableLinks
$lstDLinks = New-CheckListTab "Disable Links" $disableLinks

# ---------------------------------------------------------------
# 4. FOOTER (Preview & Log)
# ---------------------------------------------------------------
$footerLayout = New-Object System.Windows.Forms.TableLayoutPanel
$footerLayout.Dock = "Fill"
$footerLayout.ColumnCount = 1
$footerLayout.RowCount = 4
$footerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) # Verb
$footerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 40))) # Preview
$footerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 60))) # Log
$footerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40))) # Run Buttons
$mainLayout.Controls.Add($footerLayout, 0, 3)

# Verb Selection
$verbPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$verbPanel.Dock = "Fill"
$verbPanel.FlowDirection = "LeftToRight"
$lblVerb = New-Object System.Windows.Forms.Label
$lblVerb.Text = "Action (Verb):"
$lblVerb.AutoSize = $true
$lblVerb.Anchor = "Left"
$cbVerb = New-Object System.Windows.Forms.ComboBox
$cbVerb.DropDownStyle = "DropDownList"
$cbVerb.Items.AddRange($verbs)
$cbVerb.SelectedIndex = 0
$verbPanel.Controls.Add($lblVerb)
$verbPanel.Controls.Add($cbVerb)
$footerLayout.Controls.Add($verbPanel, 0, 0)

# Preview
$grpPreview = New-Object System.Windows.Forms.GroupBox
$grpPreview.Text = "Command Preview"
$grpPreview.Dock = "Fill"
$cmdBox = New-Object System.Windows.Forms.TextBox
$cmdBox.Multiline = $true
$cmdBox.ScrollBars = "Vertical"
$cmdBox.Dock = "Fill"
$cmdBox.Font = "Consolas, 10pt"
$cmdBox.ReadOnly = $true
$grpPreview.Controls.Add($cmdBox)
$footerLayout.Controls.Add($grpPreview, 0, 1)

# Log
$grpLog = New-Object System.Windows.Forms.GroupBox
$grpLog.Text = "Activity Log"
$grpLog.Dock = "Fill"
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Dock = "Fill"
$logBox.Font = "Consolas, 9pt"
$logBox.ReadOnly = $true
$grpLog.Controls.Add($logBox)
$footerLayout.Controls.Add($grpLog, 0, 2)

# Run Buttons
$runPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$runPanel.Dock = "Fill"
$runPanel.FlowDirection = "RightToLeft"
$btnExecute = New-Object System.Windows.Forms.Button
$btnExecute.Text = "EXECUTE"
$btnExecute.Width = 100
$btnExecute.BackColor = [System.Drawing.Color]::LightGreen
$btnDry = New-Object System.Windows.Forms.Button
$btnDry.Text = "Dry Run"
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy Command"

$runPanel.Controls.AddRange(@($btnExecute, $btnDry, $btnCopy))
$footerLayout.Controls.Add($runPanel, 0, 3)

# Event Handlers for Run Buttons
$btnExecute.Add_Click({ Invoke-MsDeployCommand })
$btnDry.Add_Click({ Invoke-MsDeployCommand -DryRun })
$btnCopy.Add_Click({
        $command = $cmdBox.Text.Trim()
        if ($command) { [System.Windows.Forms.Clipboard]::SetText($command) }
    })

# ===============================================================
# STATE OBJECTS
# ===============================================================

$sideControls = @{
    "Source"      = @{
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
    "Source"      = [ordered]@{
        TextBox       = $txtSrcMain
        SiteCombo     = $cbSrcSites
        BrowseButton  = $btnSrcBrowse
        RefreshButton = $btnSrcRefresh
        ProviderList  = $cbSrcProv
        CurrentMode   = "Text"
        BrowseMode    = $null
        FileFilter    = $null
    }
    "Destination" = [ordered]@{
        TextBox       = $txtDstMain
        SiteCombo     = $cbDstSites
        BrowseButton  = $btnDstBrowse
        RefreshButton = $btnDstRefresh
        ProviderList  = $cbDstProv
        CurrentMode   = "Text"
        BrowseMode    = $null
        FileFilter    = $null
    }
}

# Update label logic
$cbSrcProv.Add_SelectedIndexChanged({
        $lblSrcMain.Text = $providerMainValueLabel[$cbSrcProv.SelectedItem]
        Set-ProviderMode -Side "Source" -Provider $cbSrcProv.SelectedItem
    })
$cbDstProv.Add_SelectedIndexChanged({
        $lblDstMain.Text = $providerMainValueLabel[$cbDstProv.SelectedItem]
        Set-ProviderMode -Side "Destination" -Provider $cbDstProv.SelectedItem
    })

# Initialize
Set-ProviderMode -Side "Source" -Provider $cbSrcProv.SelectedItem
Set-ProviderMode -Side "Destination" -Provider $cbDstProv.SelectedItem
