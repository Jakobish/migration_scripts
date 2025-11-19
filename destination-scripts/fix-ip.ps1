$path="C:\Windows\System32\inetsrv\config\applicationHost.config"
$backup="$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $path $backup
(Get-Content $path).Replace("81.218.80.239","62.219.17.231") | Set-Content $path
Write-Host "Replaced IP. Backup: $backup"
