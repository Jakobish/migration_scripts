# Enhanced IIS Sites Pull Script Walkthrough

I have updated the `pull-iis-sites.ps1` script to include powerful new features for better visibility and reliability.

## New Features

### 1. New Window Mode (`-NewWindow`)
You can now spawn a separate PowerShell console window for each domain being processed. This allows you to see the real-time output of `msdeploy.exe` for multiple sites simultaneously.

**Usage:**
```powershell
.\pull-iis-sites.ps1 -Computer "10.0.0.50" -NewWindow
```

### 2. Automatic Retry Logic
The script now automatically retries failed MSDeploy operations up to 3 times with a 5-second delay between attempts. This helps handle transient network issues or temporary locks.

### 3. Enhanced Logging
- **Timestamps**: Every log entry now includes a timestamp.
- **Detailed Errors**: Full error messages and stack traces are captured.
- **Sanitization**: Passwords are automatically masked in the log files.

### 4. Worker Mode (Internal)
The script has been refactored to use a "Controller/Worker" architecture.
- **Controller**: Manages the queue and spawns processes.
- **Worker**: Handles a single domain, retries, and logging.

## How to Verify
1. **Dry Run**: Run with `-EnableWhatIf` to see what would happen without making changes.
   ```powershell
   .\pull-iis-sites.ps1 -Computer "10.0.0.50" -EnableWhatIf -NewWindow
   ```
2. **Check Logs**: Inspect the `.\logs` directory. You should see a log file for each domain (e.g., `domain.com.log`) with detailed execution history.

## Requirements
- PowerShell 7+
- MSDeploy (Web Deploy) installed on both local and remote machines.
