# DNS Zones Backup Script

This PowerShell script extracts DNS zones from a local Windows DNS server and backs up all `.dns` files to a specified directory.

## Features

- Lists all DNS zones on the local DNS server
- Copies all `.dns` files to a backup directory (default: `D:\dns-zones-backup`)
- Creates a zone list report for reference
- Provides detailed progress feedback
- Includes error handling for robust operation

## Requirements

- Windows Server with DNS Server role installed
- PowerShell 5.1 or later
- Administrator privileges (required for DNS operations)

## Usage

### Basic Usage (default backup path)
```powershell
.\backup-dns-zones.ps1
```

### Custom Backup Path
```powershell
.\backup-dns-zones.ps1 -BackupPath "E:\my-dns-backups"
```

## Output

The script creates:
1. **Backup Directory**: Contains all `.dns` files from the DNS server
2. **dns-zones-list.txt**: A text file listing all DNS zones with their properties

### Example Output
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
```

## Script Details

- **Function**: `Backup-DnsZones`
- **Cmdlets Used**: `Get-DnsServerZone`, `Get-ChildItem`, `Copy-Item`, `New-Item`
- **Error Handling**: Try/Catch blocks with detailed error messages
- **Logging**: Color-coded status messages (Green=success, Red=errors, Yellow=info)

## Notes

- The script must be run as Administrator
- DNS zone files are typically stored in `C:\Windows\System32\dns\`
- The script will create the backup directory if it doesn't exist
- Individual file copy failures won't stop the entire backup process