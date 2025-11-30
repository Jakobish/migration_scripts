# DNS Backup Script - README

## Overview
This PowerShell script (`backup-dns-zones.ps1`) extracts DNS zones from a local Windows DNS server and backs up all `.dns` files.

## What It Does
- Lists all DNS zones on the local DNS server
- Copies all `.dns` files to a backup directory (default: `D:\dns-zones-backup`)
- Creates a zone list report (`dns-zones-list.txt`)
- Provides detailed progress feedback with color-coded messages
- Includes comprehensive error handling

## Requirements
- Windows Server with DNS Server role installed
- PowerShell 5.1 or later  
- Administrator privileges

## Usage
```powershell
# Basic usage (default backup path)
.\backup-dns-zones.ps1

# Custom backup path
.\backup-dns-zones.ps1 -BackupPath "E:\my-dns-backups"
```

## Output Files
1. **Backup Directory**: Contains all `.dns` files from the DNS server
2. **dns-zones-list.txt**: Lists all DNS zones with their properties

## Script Features
- Follows PowerShell best practices and coding standards
- Uses approved PowerShell verbs (`Backup-DnsZones`)
- Includes proper error handling with Try/Catch blocks
- Color-coded progress messages (Green=success, Red=errors, Yellow=info)
- Handles individual file failures gracefully
- Auto-creates backup directory if needed

## Technical Details
- **Main Function**: `Backup-DnsZones`
- **Key Cmdlets**: `Get-DnsServerZone`, `Get-ChildItem`, `Copy-Item`, `New-Item`
- **Administrator Requirement**: `#Requires -RunAsAdministrator` directive
- **DNS Files Location**: Typically `C:\Windows\System32\dns\`

## Example Output
```
=== DNS Zones Backup Script ===
Starting DNS zones backup process...
Created backup directory: D:\dns-zones-backup
Retrieving DNS zones from local DNS server...
Found 3 DNS zone(s):
  - example.com (Primary)
  - internal.local (Primary)  
  - 1.168.192.in-addr.arpa (Primary)

Copying 3 .dns file(s) to backup directory...
  ✓ Copied: example.com.dns
  ✓ Copied: internal.local.dns
  ✓ Copied: 1.168.192.in-addr.arpa.dns

Backup completed!
Files copied: 3
Files failed: 0
Backup location: D:\dns-zones-backup
Zone list saved to: dns-zones-list.txt
=== Backup Process Complete ===
