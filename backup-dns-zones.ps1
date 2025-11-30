#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Backs up DNS zones and .dns files from local Windows DNS server.

.DESCRIPTION
    This script extracts all DNS zones from the local Windows DNS server
    and copies all .dns files to a backup directory.

.PARAMETER BackupPath
    The destination path for DNS zone backups (default: D:\dns-zones-backup)
#>

param(
    [string]$BackupPath = "D:\dns-zones-backup"
)

function Backup-DnsZones {
    param(
        [string]$DestinationPath
    )
    
    try {
        # Create backup directory if it doesn't exist
        if (!(Test-Path -Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            Write-Host "Created backup directory: $DestinationPath" -ForegroundColor Green
        }
        
        # Get all DNS zones from local DNS server
        Write-Host "Retrieving DNS zones from local DNS server..." -ForegroundColor Yellow
        $DnsZones = Get-DnsServerZone -ErrorAction Stop
        
        if ($DnsZones.Count -eq 0) {
            Write-Warning "No DNS zones found on this server."
            return
        }
        
        # Filter for forward zones only (exclude reverse lookup zones)
        $ForwardZones = $DnsZones | Where-Object {
            $_.ZoneType -eq "Primary" -and
            $_.ZoneName -notlike "*.in-addr.arpa" -and
            $_.ZoneName -notlike "*.ip6.arpa" -and
            $_.ZoneName -notlike "*.arpa"
        }
        
        if ($ForwardZones.Count -eq 0) {
            Write-Warning "No forward zones found on this server."
            return
        }
        
        Write-Host "Found $($ForwardZones.Count) forward zone(s):" -ForegroundColor Green
        
        # Display forward zone information
        foreach ($Zone in $ForwardZones) {
            Write-Host "  - $($Zone.ZoneName)" -ForegroundColor Cyan
        }
        
        # Find .dns files for forward zones only
        $DnsFilesPath = "${env:SystemRoot}\System32\dns"
        $ZoneDnsFiles = @()
        
        foreach ($Zone in $ForwardZones) {
            $ZoneFileName = "$($Zone.ZoneName).dns"
            $ZoneFilePath = Join-Path -Path $DnsFilesPath -ChildPath $ZoneFileName
            
            if (Test-Path -Path $ZoneFilePath) {
                $ZoneDnsFiles += Get-Item -Path $ZoneFilePath
            }
            else {
                Write-Host "  ⚠ Warning: $($ZoneFileName) not found in DNS directory" -ForegroundColor Yellow
            }
        }
        
        if ($ZoneDnsFiles.Count -eq 0) {
            Write-Warning "No .dns files found for forward zones in $DnsFilesPath"
            return
        }
        
        Write-Host "`nCopying $($ZoneDnsFiles.Count) forward zone .dns file(s) to backup directory..." -ForegroundColor Yellow
        
        $CopiedFiles = 0
        $FailedFiles = 0
        
        foreach ($DnsFile in $ZoneDnsFiles) {
            try {
                $DestinationFile = Join-Path -Path $DestinationPath -ChildPath $DnsFile.Name
                Copy-Item -Path $DnsFile.FullName -Destination $DestinationFile -Force -ErrorAction Stop
                Write-Host "  ✓ Copied: $($DnsFile.Name)" -ForegroundColor Green
                $CopiedFiles++
            }
            catch {
                Write-Host "  ✗ Failed to copy: $($DnsFile.Name) - $($_.Exception.Message)" -ForegroundColor Red
                $FailedFiles++
            }
        }
        
        # Summary
        Write-Host "`nBackup completed!" -ForegroundColor Green
        Write-Host "Files copied: $CopiedFiles" -ForegroundColor Green
        if ($FailedFiles -gt 0) {
            Write-Host "Files failed: $FailedFiles" -ForegroundColor Red
        }
        Write-Host "Backup location: $DestinationPath" -ForegroundColor Cyan
        
        # Save zone list to text file
        $ZoneListFile = Join-Path -Path $DestinationPath -ChildPath "dns-zones-list.txt"
        $DnsZones | Select-Object ZoneName, ZoneType, IsAutoCreated, IsDsIntegrated | Format-Table -AutoSize | Out-File -FilePath $ZoneListFile -Encoding UTF8
        Write-Host "Zone list saved to: dns-zones-list.txt" -ForegroundColor Cyan
        
    }
    catch {
        Write-Error "Failed to backup DNS zones: $($_.Exception.Message)"
        throw
    }
}

# Main execution
Write-Host "=== DNS Zones Backup Script ===" -ForegroundColor Magenta
Write-Host "Starting DNS zones backup process..." -ForegroundColor Yellow

Backup-DnsZones -DestinationPath $BackupPath

Write-Host "=== Backup Process Complete ===" -ForegroundColor Magenta