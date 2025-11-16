Import-Module WebAdministration
$iisSites = Get-ChildItem IIS:\Sites
foreach ($site in $iisSites) {
  $appPool = (Get-Item "IIS:\Sites\$($site.Name)").applicationPool
  if (-not $appPool) { continue }
  $user = "$($site.Name)_web"
  $pass = [System.Web.Security.Membership]::GeneratePassword(16,3)
  net user $user $pass /add /y 2>$null
  Set-ItemProperty "IIS:\AppPools\$appPool" -Name processModel -Value @{userName=$user; password=$pass; identityType=3}
  Write-Host "Updated $site ($user)"
}
