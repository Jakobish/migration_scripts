param(
  [int]$StartIndex=0,
  [int]$Batch=10,
  [switch]$WhatIf
)
$sites = (Get-ChildItem IIS:\Sites).Name
$end = [math]::Min($sites.Count-1, $StartIndex+$Batch-1)
$chunk = $sites[$StartIndex..$end]
foreach ($s in $chunk) {
  $ts=(Get-Date -Format "yyyyMMdd_HHmmss")
  $log="C:\logs\deploy_${s}_$ts.txt"
  $cmd="msdeploy -verb:sync -source:appHostConfig=""$s"" -dest:appHostConfig=""$s"",computerName=...,userName=...,password=..."
  if ($WhatIf) {
    "$cmd" | Out-File $log
  } else {
    cmd /c "$cmd" > $log 2>&1
  }
}
