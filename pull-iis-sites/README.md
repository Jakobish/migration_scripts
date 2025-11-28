# IIS Sites Pull Tool - Documentation

## Overview

Simplified PowerShell script for pulling IIS site configurations from a remote server using MSDeploy. Designed for one-time migration projects.

## Features

- **Configuration File**: All settings in JSON (including credentials)
- **Parallel Execution**: Process multiple sites simultaneously
- **Automatic Retries**: Retry failed pulls up to 3 times
- **Detailed Logging**: Per-domain log files with timestamps

## Setup

### 1. Configuration File

Create or edit `pull-iis-sites.config.json`:

```json
{
  "Computer": "10.0.0.50",
  "Username": "domain\\admin",
  "Password": "YourPasswordHere",
  "DomainListFile": "./domains.txt",
  "LogDir": "./logs",
  "MaxParallel": 8,
  "MSDeployPath": "C:\\Program Files\\IIS\\Microsoft Web Deploy V3\\msdeploy.exe",
  "MaxRetries": 3,
  "RetryDelaySeconds": 5,
  "WhatIf": false
}
```

### 2. Domain List File

Create `domains.txt` with one domain per line:

```text
site1.example.com
site2.example.com
# This is a comment
site3.example.com
```

## Usage

### Basic

```powershell
.\pull-iis-sites.ps1
```

### Custom Config File

```powershell
.\pull-iis-sites.ps1 -ConfigFile .\my-config.json
```

### Dry Run (Preview)

Set `"WhatIf": true` in config file to preview without making changes.

## Configuration Options

| Setting | Required | Default | Description |
|---------|----------|---------|-------------|
| `Computer` | Yes | - | Remote server hostname/IP |
| `Username` | Yes | - | Authentication username |
| `Password` | Yes | - | Authentication password |
| `DomainListFile` | Yes | - | Path to domain list file |
| `LogDir` | No | `./logs` | Directory for log files |
| `MaxParallel` | No | `8` | Max concurrent operations |
| `MSDeployPath` | No | `C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe` | Path to msdeploy.exe |
| `MaxRetries` | No | `3` | Retry attempts per domain |
| `RetryDelaySeconds` | No | `5` | Delay between retries |
| `WhatIf` | No | `false` | Preview mode |

## Output

- Console shows real-time progress for each domain
- Logs saved to `LogDir` (one file per domain: `domain.log`)
- Summary report at completion

## Requirements

- PowerShell 7+
- MSDeploy (Web Deploy) installed
- Network access to remote IIS server

## Security Note

⚠️ The config file contains plaintext credentials. For one-time migrations this is acceptable, but secure the file appropriately (e.g., set file permissions, delete after migration).
