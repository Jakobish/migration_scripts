try {
    Import-Module WebAdministration -ErrorAction Stop
}
catch {
    Import-Module WebAdministration -SkipEditionCheck -ErrorAction Stop
}

$hasIISAdministration = $false
try {
    Import-Module IISAdministration -ErrorAction Stop
    $hasIISAdministration = $true
}
catch {
    Write-Verbose "IISAdministration module is unavailable; falling back to WebAdministration providers."
}

if (-not (Get-PSDrive -Name IIS -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name IIS -PSProvider WebAdministration -Root IIS:\ | Out-Null
}

Add-Type -AssemblyName System.Web

$configPath = "MACHINE/WEBROOT/APPHOST"
$sites = if ($hasIISAdministration -and (Get-Command Get-IISSite -ErrorAction SilentlyContinue)) {
    Get-IISSite
}
else {
    Get-ChildItem IIS:\Sites
}

$msDeployPath = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"

foreach ($site in $sites) {
    $siteName = $site.Name
    $anonAuth = Get-WebConfigurationProperty -PSPath $configPath -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name "." -Location $siteName
    if (-not $anonAuth) {
        Write-Warning "Anonymous authentication settings missing for $siteName. Skipping."
        continue
    }

    $anonUser = $anonAuth.userName

    if ([string]::IsNullOrWhiteSpace($anonUser)) {
        Write-Warning "Anonymous user not defined for $siteName. Skipping."
        continue
    }

    $password = [System.Web.Security.Membership]::GeneratePassword(20, 4)

    & net.exe user $anonUser *> $null
    $userExists = $LASTEXITCODE -eq 0

    if ($userExists) {
        & net.exe user $anonUser $password /passwordchg:no /expires:never *> $null
    }
    else {
        & net.exe user $anonUser $password /add /y /passwordchg:no /expires:never *> $null
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to create or update local user $anonUser for $siteName. Skipping."
        continue
    }

    Set-WebConfigurationProperty -PSPath $configPath -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name userName -Value $anonUser -Location $siteName | Out-Null
    Set-WebConfigurationProperty -PSPath $configPath -Filter "system.webServer/security/authentication/anonymousAuthentication" -Name password -Value $password -Location $siteName | Out-Null

    $appPoolName = $null
    $sitePhysicalPath = $null
    if ($hasIISAdministration -and ($site -is [Microsoft.Web.Administration.Site])) {
        $rootApplication = $site.Applications | Where-Object { $_.Path -eq "/" } | Select-Object -First 1
        if ($rootApplication) {
            $appPoolName = $rootApplication.ApplicationPoolName
            $rootVirtualDir = $rootApplication.VirtualDirectories | Where-Object { $_.Path -eq "/" } | Select-Object -First 1
            if ($rootVirtualDir) {
                $sitePhysicalPath = $rootVirtualDir.PhysicalPath
            }
        }
    }

    if (-not $appPoolName) {
        $sitePath = "IIS:\Sites\$siteName"
        $appPoolName = (Get-Item $sitePath).applicationPool
        if ($appPoolName -is [array]) {
            $appPoolName = $appPoolName[0]
        }
        if (-not $sitePhysicalPath) {
            $sitePhysicalPath = (Get-Item $sitePath).physicalPath
        }
    }

    if ([string]::IsNullOrWhiteSpace($appPoolName)) {
        Write-Warning "No application pool associated with $siteName. Skipping app pool update."
        continue
    }

    $appPoolPath = "IIS:\AppPools\$appPoolName"
    $appPoolExists = $false
    if ($hasIISAdministration -and (Get-Command Get-IISAppPool -ErrorAction SilentlyContinue)) {
        $appPoolExists = $null -ne (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue)
    }
    else {
        $appPoolExists = Test-Path $appPoolPath
    }

    if (-not $appPoolExists) {
        Write-Warning "Application pool $appPoolName for $siteName was not found."
        continue
    }

    if ($hasIISAdministration -and (Get-Command Set-IISAppPool -ErrorAction SilentlyContinue)) {
        Set-IISAppPool -Name $appPoolName -processModel.identityType SpecificUser -processModel.userName $anonUser -processModel.password $password | Out-Null
    }
    else {
        Set-ItemProperty $appPoolPath -Name processModel -Value @{
            identityType = "SpecificUser"
            userName     = $anonUser
            password     = $password
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($sitePhysicalPath)) {
        $expandedPhysicalPath = [Environment]::ExpandEnvironmentVariables($sitePhysicalPath)
        if (Test-Path $expandedPhysicalPath) {
            if (Test-Path $msDeployPath) {
                $escapedPath = $expandedPhysicalPath.Replace('"', '""')
                $escapedUser = $anonUser.Replace('"', '""')
                $msDeployArgs = "`"$msDeployPath`" -verb:sync -source:setAcl -dest:setAcl=`"$escapedPath`",setAclUser=`"$escapedUser`",setAclAccess=ReadAndExecute,setAclResourceType=Directory"
                & cmd.exe /c $msDeployArgs | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to set ACL on $expandedPhysicalPath for $siteName."
                }
            }
            else {
                Write-Warning "msdeploy not found at $msDeployPath. Unable to set ACLs for $siteName."
            }
        }
        else {
            Write-Warning "Physical path $expandedPhysicalPath for $siteName not found."
        }
    }
    else {
        Write-Warning "Physical path for $siteName could not be determined."
    }

    Write-Host "Updated $siteName anonymous user and application pool ($anonUser)."
}
