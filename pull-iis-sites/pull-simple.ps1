# ==========================
# CONFIG
# ==========================
$MsDeployPath = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"
$ServerIP = "10.0.0.50"
$UserName = "administrator"
$Password = "pwd123"
$AuthType = "NTLM"

$DomainsFile = "domains.txt"
$LogsDir = "logs"

$MaxDomainsToProcess = 4       # כמה אתרים לעבד
$Parallelism = 2               # כמה חלונות cmd במקביל

# ==========================
# PREP
# ==========================
if (-not (Test-Path $DomainsFile)) { Write-Error "Domains file not found"; exit 1 }
if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir | Out-Null }

$Domains = Get-Content $DomainsFile | Where-Object { $_.Trim() -ne "" }
$SelectedDomains = $Domains | Select-Object -First $MaxDomainsToProcess

Write-Host "Domains in file         : $($Domains.Count)"
Write-Host "Domains to process      : $MaxDomainsToProcess"
Write-Host ""

# ==========================
# RUN JOBS (visible CMD)
# ==========================
$Jobs = @()

foreach ($Domain in $SelectedDomains) {

    $LogFile = Join-Path $LogsDir "$Domain.log.txt"

    $CmdLine = "`"$MsDeployPath`" -verb:sync -source:appHostConfig=`"$Domain`",computerName=`"$ServerIP`",userName=`"$UserName`",password=`"$Password`",authType=`"$AuthType`" -dest:auto -allowUntrusted -enableLink:AppPoolExtension"

    $Wrapped = "echo Running $Domain... & $CmdLine & echo. & echo Log: $LogFile & pause"

    $Job = Start-Job -ScriptBlock {
        param($Domain, $Wrapped, $LogFile)

        "`n===== $(Get-Date) =====" | Out-File $LogFile -Append
        $Wrapped                 | Out-File $LogFile -Append

        Start-Process cmd.exe -ArgumentList "/k $Wrapped"

    } -ArgumentList $Domain, $Wrapped, $LogFile

    $Jobs += $Job

    # להגביל כמות חלונות פעילים
    while ( (Get-Job -State Running).Count -ge $Parallelism ) {
        Start-Sleep -Seconds 1
    }
}

Write-Host "Waiting for all jobs..."
Wait-Job $Jobs | Out-Null

Write-Host "Completed."