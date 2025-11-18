#Requires -RunAsAdministrator
<#
    Target: Windows Server 2019+
#>

#region Helper Functions

function Write-Section {
    param(
        [string]$Title
    )
    Write-Host ""
    Write-Host "==============================="
    Write-Host " $Title"
    Write-Host "==============================="
}

function Pause-Continue {
    param(
        [string]$Message = "Press any key to continue..."
    )
    Write-Host ""
    Write-Host $Message
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Test-IsServerCore {
    # בדיקה פשוטה אם זה Server Core (ללא Shell גרפי)
    return -not (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name InstallationType -ErrorAction SilentlyContinue |
        Where-Object { $_.InstallationType -like "*Server*" -and $_.InstallationType -notlike "*Core*" } )
}

#endregion

#region System / Restore

function New-SystemRestoreIfPossible {
    Write-Section "Create Restore Point (if supported)"

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        if ($os.ProductType -eq 1) {
            # Workstation – אפשרות ל־System Restore
            Write-Host "Creating restore point on client OS..." -ForegroundColor Cyan
            Checkpoint-Computer -Description "Pre-ServerSetupUtility" -RestorePointType "MODIFY_SETTINGS"
        }
        else {
            Write-Host "Server OS – System Restore is generally not available. Skipping." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Failed to create restore point: $($_.Exception.Message)"
    }
}

#endregion

#region Windows / Updates / Basic Config

function Enable-RemoteDesktop {
    Write-Section "Enable Remote Desktop"

    try {
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Write-Host "Remote Desktop enabled and firewall rules opened." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to enable RDP: $($_.Exception.Message)"
    }
}

function Set-BasicFirewall {
    Write-Section "Configure basic firewall rules"

    try {
        # דוגמה: משאיר את Windows Firewall פעיל, מוודא פרופילים בסיסיים
        Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
        Write-Host "Firewall profiles ensured enabled." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to configure firewall profiles: $($_.Exception.Message)"
    }
}

function Disable-TelemetryLikeSettings {
    Write-Section "Basic 'Telemetry' / Data Collection Tweaks"

    try {
        # לא קיצוני – רק דוגמאות "קלות"
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        New-ItemProperty -Path $path -Name "AllowTelemetry" -PropertyType DWord -Value 0 -Force | Out-Null

        Write-Host "Telemetry set to minimal (AllowTelemetry = 0 under Policies)." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to apply telemetry tweaks: $($_.Exception.Message)"
    }
}

#endregion

#region IIS & Web Deploy

function Install-IISAndBaseFeatures {
    Write-Section "Install IIS + common features"

    $features = @(
        "Web-Server",
        "Web-WebServer",
        "Web-Common-Http",
        "Web-Default-Doc",
        "Web-Static-Content",
        "Web-Http-Errors",
        "Web-Http-Logging",
        "Web-Request-Monitor",
        "Web-Stat-Compression",
        "Web-Filtering",
        "Web-Mgmt-Tools",
        "Web-Mgmt-Console",
        "Web-Scripting-Tools",
        "Web-ISAPI-Ext",
        "Web-ISAPI-Filter",
        "Web-Asp-Net45",
        "Web-Net-Ext45"
    )

    foreach ($f in $features) {
        try {
            Write-Host "Installing feature: $f..."
            Add-WindowsFeature -Name $f -IncludeManagementTools -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning "Failed to install feature '$f': $($_.Exception.Message)"
        }
    }

    Write-Host "IIS base installation – done (check individual feature status as needed)." -ForegroundColor Green
}

function Create-BasicIISSite {
    [CmdletBinding()]
    param(
        [string]$SiteName = "MySite",
        [string]$PhysicalPath = "C:\inetpub\mysite",
        [int]$Port = 8080
    )

    Write-Section "Create IIS site '$SiteName'"

    Import-Module WebAdministration -ErrorAction SilentlyContinue

    if (-not (Get-Module WebAdministration)) {
        Write-Warning "WebAdministration module not available; cannot manage IIS via PowerShell."
        return
    }

    try {
        if (-not (Test-Path $PhysicalPath)) {
            New-Item -ItemType Directory -Path $PhysicalPath -Force | Out-Null
            "Hello from $SiteName" | Out-File (Join-Path $PhysicalPath "index.html") -Encoding utf8
        }

        if (Get-Website | Where-Object { $_.Name -eq $SiteName }) {
            Write-Host "Site '$SiteName' already exists. Skipping creation." -ForegroundColor Yellow
        }
        else {
            New-Website -Name $SiteName -Port $Port -PhysicalPath $PhysicalPath -Force | Out-Null
            Write-Host "Site '$SiteName' created on port $Port." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to create IIS site '$SiteName': $($_.Exception.Message)"
    }
}

function Install-WebDeployIfPresent {
    Write-Section "Register Web Deploy PowerShell snapin (if installed)"

    try {
        Add-PSSnapin WDeploySnapin3.0 -ErrorAction Stop
        Write-Host "WDeploySnapin3.0 loaded successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "Web Deploy PowerShell snapin not found. Make sure Web Deploy 3.x is installed."
        Write-Host "Download: https://www.iis.net/downloads/microsoft/web-deploy" -ForegroundColor DarkCyan
    }
}

function Set-WebDeployACL-ForSiteContent {
    [CmdletBinding()]
    param(
        [string]$SitePath = "C:\inetpub\mysite",
        [string]$User = "IIS AppPool\DefaultAppPool"
    )

    Write-Section "Set ACL on site content using standard PowerShell ACL (not msdeploy)"

    try {
        if (-not (Test-Path $SitePath)) {
            Write-Warning "Path '$SitePath' does not exist; cannot set ACL."
            return
        }

        $acl = Get-Acl $SitePath
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $User,
            "Read, ReadAndExecute, ListDirectory",
            "ContainerInherit, ObjectInherit",
            "None",
            "Allow"
        )
        $acl.SetAccessRule($rule)
        Set-Acl -Path $SitePath -AclObject $acl

        Write-Host "Granted R/X permissions on '$SitePath' for '$User'." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to set ACL: $($_.Exception.Message)"
    }
}

#endregion

#region Hardening IIS (basic)

function Harden-IISBasic {
    Write-Section "Basic IIS hardening (very conservative)"

    Import-Module WebAdministration -ErrorAction SilentlyContinue
    if (-not (Get-Module WebAdministration)) {
        Write-Warning "WebAdministration module not available; skipping IIS hardening."
        return
    }

    try {
        # Disable directory browsing globally
        Set-WebConfigurationProperty -Filter /system.webServer/directoryBrowse `
            -PSPath IIS:\ `
            -Name enabled `
            -Value False

        # Example: remove headers X-Powered-By, ServerTokens-like
        $configPath = "MACHINE/WEBROOT/APPHOST"
        Clear-WebConfiguration -PSPath $configPath `
            -Filter "system.webServer/httpProtocol/customHeaders/add[@name='X-Powered-By']" `
            -ErrorAction SilentlyContinue

        Write-Host "Directory browsing disabled and X-Powered-By header cleared (if existed)." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed during IIS hardening: $($_.Exception.Message)"
    }
}

#endregion

#region Menu

function Show-MainMenu {
    Clear-Host
    Write-Host "========================================="
    Write-Host "  Server Setup Utility (Chris Titus style)"
    Write-Host "  Target: Windows Server 2019+"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "[1] Create system restore point (where supported)"
    Write-Host "[2] Enable RDP + basic firewall"
    Write-Host "[3] Basic telemetry / data-collection tweaks"
    Write-Host "[4] Install IIS + core web features"
    Write-Host "[5] Create basic IIS site (MySite on port 8080)"
    Write-Host "[6] Register Web Deploy PowerShell snapin (if installed)"
    Write-Host "[7] Set ACL on site content folder"
    Write-Host "[8] Basic IIS hardening"
    Write-Host ""
    Write-Host "[P] Run 'Profile: Web Server Quick Setup' (2,3,4,5,7,8)"
    Write-Host ""
    Write-Host "[Q] Quit"
    Write-Host ""
}

function Run-WebServerQuickProfile {
    Write-Section "Profile: Web Server Quick Setup"

    Enable-RemoteDesktop
    Set-BasicFirewall
    Disable-TelemetryLikeSettings
    Install-IISAndBaseFeatures
    Create-BasicIISSite -SiteName "MySite" -PhysicalPath "C:\inetpub\mysite" -Port 8080
    Set-WebDeployACL-ForSiteContent -SitePath "C:\inetpub\mysite" -User "IIS AppPool\DefaultAppPool"
    Harden-IISBasic

    Write-Host ""
    Write-Host "Profile completed. Review output above and test the server." -ForegroundColor Green
}

#endregion

#region Main Loop

do {
    Show-MainMenu
    $choice = Read-Host "Select an option"

    switch ($choice.ToUpper()) {
        '1' {
            New-SystemRestoreIfPossible
            Pause-Continue
        }
        '2' {
            Enable-RemoteDesktop
            Set-BasicFirewall
            Pause-Continue
        }
        '3' {
            Disable-TelemetryLikeSettings
            Pause-Continue
        }
        '4' {
            Install-IISAndBaseFeatures
            Pause-Continue
        }
        '5' {
            $name = Read-Host "Site name (default: MySite)"
            if ([string]::IsNullOrWhiteSpace($name)) { $name = "MySite" }

            $path = Read-Host "Physical path (default: C:\inetpub\mysite)"
            if ([string]::IsNullOrWhiteSpace($path)) { $path = "C:\inetpub\mysite" }

            $portInput = Read-Host "Port (default: 8080)"
            if ([string]::IsNullOrWhiteSpace($portInput)) { $portInput = "8080" }
            [int]$port = $portInput

            Create-BasicIISSite -SiteName $name -PhysicalPath $path -Port $port
            Pause-Continue
        }
        '6' {
            Install-WebDeployIfPresent
            Pause-Continue
        }
        '7' {
            $path = Read-Host "Folder path (default: C:\inetpub\mysite)"
            if ([string]::IsNullOrWhiteSpace($path)) { $path = "C:\inetpub\mysite" }

            $user = Read-Host "User to grant R/X (default: IIS AppPool\DefaultAppPool)"
            if ([string]::IsNullOrWhiteSpace($user)) { $user = "IIS AppPool\DefaultAppPool" }

            Set-WebDeployACL-ForSiteContent -SitePath $path -User $user
            Pause-Continue
        }
        '8' {
            Harden-IISBasic
            Pause-Continue
        }
        'P' {
            Run-WebServerQuickProfile
            Pause-Continue
        }
        'Q' {
            break
        }
        default {
            Write-Host "Invalid choice." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }

} while ($true)

#endregion