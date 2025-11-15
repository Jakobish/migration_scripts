$path="C:\Windows\System32\inetsrv\config\applicationHost.config"
$backup="$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $path $backup
(Get-Content $path).Replace("OLD_IP","NEW_IP") | Set-Content $path
Write-Host "Replaced IP. Backup: $backup"
