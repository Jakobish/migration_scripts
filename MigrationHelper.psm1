
using namespace System.Security.AccessControl

function Write-Log {
    param(
        [Parameter(Mandatory)][ValidateSet("INFO","WARN","ERROR")] [string]$Level,
        [Parameter(Mandatory)][string]$Message,
        [string]$LogPath = $script:GlobalLogPath
    )
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Level, $Message
    Write-Host $line
    if ($LogPath) { Add-Content -Path $LogPath -Value $line -Encoding UTF8 }
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
    (Resolve-Path $Path).Path
}

function Save-Json {
    param([Parameter(Mandatory)]$Object,
          [Parameter(Mandatory)][string]$Path)
    $dir = Split-Path $Path
    Ensure-Directory -Path $dir | Out-Null
    $json = $Object | ConvertTo-Json -Depth 6
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

function Load-Json {
    param([Parameter(Mandatory)][string]$Path)
    if (!(Test-Path $Path)) { throw "JSON file not found: $Path" }
    Get-Content -Raw -Path $Path | ConvertFrom-Json
}

function Get-Sddl {
    param([Parameter(Mandatory)][string]$Path)
    $acl = Get-Acl -Path $Path -ErrorAction Stop
    $acl.Sddl
}

function Set-Sddl {
    param([Parameter(Mandatory)][string]$Path,
          [Parameter(Mandatory)][string]$Sddl)
    $acl = New-Object FileSecurity
    $acl.SetSecurityDescriptorSddlForm($Sddl)
    Set-Acl -Path $Path -AclObject $acl
}

function Copy-FromZip {
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$Destination
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination, $true)
}

function New-AppPoolIfMissing {
    param(
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet('ApplicationPoolIdentity','NetworkService','LocalService','SpecificUser')] [string]$IdentityType = 'ApplicationPoolIdentity',
        [string]$UserName,
        [string]$Password
    )
    Import-Module WebAdministration | Out-Null
    if (-not (Test-Path "IIS:\AppPools\$Name")) {
        New-WebAppPool -Name $Name | Out-Null
        Write-Log INFO "Created AppPool '$Name'"
    }
    switch ($IdentityType) {
        'ApplicationPoolIdentity' { Set-ItemProperty "IIS:\AppPools\$Name" -Name ProcessModel.IdentityType -Value 4 }
        'NetworkService'          { Set-ItemProperty "IIS:\AppPools\$Name" -Name ProcessModel.IdentityType -Value 2 }
        'LocalService'            { Set-ItemProperty "IIS:\AppPools\$Name" -Name ProcessModel.IdentityType -Value 1 }
        'SpecificUser' {
            if (-not $UserName -or -not $Password) {
                Write-Log WARN "AppPool '$Name' requires SpecificUser credentials; none provided. Leaving as ApplicationPoolIdentity."
            } else {
                Set-ItemProperty "IIS:\AppPools\$Name" -Name processModel -Value @{identityType='SpecificUser'; userName=$UserName; password=$Password}
            }
        }
    }
}

function New-WebsiteIfMissing {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$PhysicalPath,
        [string]$AppPool,
        [string[]]$HttpBindings,
        [Array]$HttpsBindings # array of @{ ip="*"; port=443; host="example.com"; thumbprint="..." }
    )
    Import-Module WebAdministration | Out-Null
    Ensure-Directory -Path $PhysicalPath | Out-Null

    if (-not (Test-Path "IIS:\Sites\$Name")) {
        New-Website -Name $Name -PhysicalPath $PhysicalPath -Port 0 | Out-Null  # create placeholder
        Write-Log INFO "Created Website '$Name' at $PhysicalPath"
    } else {
        Set-ItemProperty "IIS:\Sites\$Name" -Name physicalPath -Value $PhysicalPath
    }
    if ($AppPool) {
        Set-ItemProperty "IIS:\Sites\$Name" -Name applicationPool -Value $AppPool
    }

    # Clear existing bindings
    $site = Get-Item "IIS:\Sites\$Name"
    $site.Bindings.Collection.Clear()

    foreach ($b in $HttpBindings) {
        New-WebBinding -Name $Name -Protocol http -Port $b.Port -IPAddress $b.IP -HostHeader $b.Host | Out-Null
    }

    foreach ($hb in $HttpsBindings) {
        $cert = if ($hb.thumbprint) { Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $hb.thumbprint } }
        if ($cert) {
            New-WebBinding -Name $Name -Protocol https -Port $hb.Port -IPAddress $hb.IP -HostHeader $hb.Host | Out-Null
            # Attach certificate
            Push-Location IIS:\SslBindings
            try {
                if (-not (Test-Path "0.0.0.0!$($hb.Port)")) {
                    New-Item "0.0.0.0!$($hb.Port)" -Thumbprint $cert.Thumbprint -SSLFlags 1 | Out-Null
                }
            } finally { Pop-Location }
        } else {
            Write-Log WARN "Missing certificate for host '$($hb.Host)'; https binding skipped."
        }
    }
}

function Parse-BindingInfo {
    param([Parameter(Mandatory)][string]$BindingString)
    # example bindingInformation: "IP:PORT:HOST"
    $parts = $BindingString.Split(':')
    @{ IP=$parts[0]; Port=[int]$parts[1]; Host=$parts[2] }
}

Export-ModuleMember -Function * -Alias *
