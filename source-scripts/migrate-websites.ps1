param(
    [int]$StartIndex = 0,
    [int]$BatchSize = 1,
    [string]$DestinatoinServerIP = "1.1.1.1",
    [string]$DestUsername = "",
    [SecureString]$DestPassword = "",
    [switch]$WhatIf
)

# ---- SETTINGS ----
$mainLog   = ".\migrate-websites.log"
$logsDir   = ".\site-logs"
$msdeploy  = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"

if (!(Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

# Load sites
Import-Module WebAdministration
$sites = Get-ChildItem IIS:\Sites | Select-Object Name, ID, State, Bindings, PhysicalPath

$total = $sites.Count
"Loaded $total sites" | Tee-Object -FilePath $mainLog -Append

# Batch window
$subset = $sites | Select-Object -Skip $StartIndex -First $BatchSize
"Processing batch starting at index $StartIndex, size $BatchSize" | Tee-Object -FilePath $mainLog -Append

foreach ($site in $subset)
{
    $name = $site.Name
  #  $phys = $site.PhysicalPath
 #  $pool = (Get-WebConfigurationProperty "system.applicationHost/sites/site[@name='$name']/application[@path='/']" -Name applicationPool)

    # If app pool returned as object, extract string
 #   if ($pool -is [System.Array]) {
  #      $pool = $pool[0]
  #  }

   # $appPoolIdentity = "IIS APPPOOL\$pool"

    $timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
    $siteLog = "$logsDir\$name-$timestamp.log"

    "======== Migrating site: $name ========" | Tee-Object -FilePath $mainLog -Append
    "Log file: $siteLog" | Tee-Object -FilePath $mainLog -Append

    #
    # ---- Primary site sync ----
    #
    $cmdSync = @(
        "`"$msdeploy`"",
        "-verb:sync",
        "-source:appHostConfig=`"$name`"",
        "-dest:auto,computerName=`"$DestinatoinServerIP`",includeACLs=`"true`"",
        "-enableLink:AppPoolExtension"
        
#      "-enableLink:ContentExtension",
#     "-enableLink:CertificateExtension",
#        "-retryAttempts:3",
 #       "-retryInterval:5000"
    ) -join " "

  
    # WHAT-IF
    if ($WhatIf)
    {
        "WHATIF: $cmdSync" | Tee-Object -FilePath $mainLog -Append
       # "WHATIF: $cmdACL"  | Tee-Object -FilePath $mainLog -Append

        "WHATIF: $cmdSync" | Out-File $siteLog -Encoding UTF8
       # "WHATIF: $cmdACL"  | Out-File $siteLog -Append -Encoding UTF8

        continue
    }

    try {
        # execute sync
        & cmd.exe /c $cmdSync 2>&1 | Tee-Object -FilePath $siteLog -Append

        # execute ACL assignment
       # & cmd.exe /c $cmdACL 2>&1  | Tee-Object -FilePath $siteLog -Append
    }
    catch {
        "ERROR on site $sitename : $_" | Tee-Object -FilePath $mainLog -Append
        "ERROR: $_" | Out-File $siteLog -Append
    }

    "`n" | Add-Content $mainLog
}

"Batch completed." | Tee-Object -FilePath $mainLog -Append