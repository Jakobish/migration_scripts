# GUI Migration Tool - User Guide

> Visual command builder for Microsoft Web Deploy (msdeploy) - Build and execute IIS migration commands with an intuitive graphical interface

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Launching the GUI](#launching-the-gui)
- [User Interface Overview](#user-interface-overview)
- [Configuration Sections](#configuration-sections)
- [Usage Guide](#usage-guide)
- [Command Preview and Execution](#command-preview-and-execution)
- [State Management](#state-management)
- [Common Scenarios](#common-scenarios)
- [Troubleshooting](#troubleshooting)
- [Advanced Features](#advanced-features)

## Overview

The **GUI Migration Tool** (`gui-migrate.ps1`) is a PowerShell-based graphical application that simplifies the creation and execution of complex Microsoft Web Deploy (msdeploy) commands. Instead of manually constructing command-line arguments, you can visually configure all migration parameters and see a real-time preview of the generated command.

### Key Features

- ✓ **Visual Command Builder** - Point-and-click interface for all msdeploy options
- ✓ **Real-time Preview** - See the exact command that will be executed
- ✓ **Configuration Management** - Save and load migration configurations
- ✓ **Side-by-side Setup** - Configure source and destination in one view
- ✓ **Comprehensive Options** - Access all msdeploy verbs, providers, flags, rules, and links
- ✓ **Activity Logging** - Detailed execution logs with timestamps
- ✓ **Error Validation** - Automatic prerequisite checking

## Prerequisites

### Required Software

1. **Windows Operating System**
   - Windows Server 2012 R2 or later
   - Windows 10/11

2. **PowerShell**
   - Version 5.1 or later
   - Must be run as Administrator

3. **Microsoft Web Deploy V3**
   - Must be installed at: `C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe`
   - Download: [Microsoft Web Deploy](https://www.microsoft.com/en-us/download/details.aspx?id=43717)

4. **IIS Management Tools**
   - WebAdministration PowerShell module (loaded automatically)

### Permission Requirements

- **Administrator privileges** are required
- The script enforces elevation and will show an error if not run as Administrator
- UAC must be approved when launching via batch files

## Launching the GUI

### Method 1: Direct PowerShell Execution

```powershell
.\gui-migrate.ps1
```

Run this command from an elevated PowerShell session in the migration scripts directory.

### Method 2: Windows Batch Launcher (Recommended for Windows)

```cmd
start-gui.bat
```

Double-click `start-gui.bat` or run from command prompt. This automatically:
- Launches PowerShell with administrator privileges
- Handles UAC elevation
- Validates prerequisites

### Method 3: macOS Command Launcher

```bash
./start-gui.command
```

For macOS users with PowerShell Core installed. Requires:
- PowerShell Core (`pwsh`)
- Administrator access via sudo

### Method 4: Remote Execution

```powershell
.\invoke-remote-gui.ps1 -ComputerName "192.168.1.100" -Username "admin"
```

Launch the GUI on a remote server. See the main [README.md](../README.md) for details.

## User Interface Overview

The GUI is organized into several key sections:

```
┌─────────────────────────────────────────────────────┐
│  Global Settings (Verb Selection)                   │
├─────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐        │
│  │  Source Config   │  │  Destination     │        │
│  │                  │  │  Config          │        │
│  │  - Provider      │  │  - Provider      │        │
│  │  - Connection    │  │  - Connection    │        │
│  │  - Authentication│  │  - Authentication│        │
│  │  - Options       │  │  - Options       │        │
│  └──────────────────┘  └──────────────────┘        │
├─────────────────────────────────────────────────────┤
│  Advanced Settings (Tab Control)                    │
│  - Global Flags                                     │
│  - Deployment Rules                                 │
│  - Enable Link Extensions                           │
│  - Disable Link Extensions                          │
├─────────────────────────────────────────────────────┤
│  Action Panel (Save/Load/Execute Buttons)           │
├─────────────────────────────────────────────────────┤
│  Command Preview (Read-only, real-time)             │
├─────────────────────────────────────────────────────┤
│  Execute/Copy Buttons                               │
├─────────────────────────────────────────────────────┤
│  Activity Log (Execution output)                    │
└─────────────────────────────────────────────────────┘
```

### UI Components

| Component | Description |
|-----------|-------------|
| **Verb Dropdown** | Select the msdeploy operation (sync, dump, delete, etc.) |
| **Source Panel** | Configure the source provider and connection settings |
| **Destination Panel** | Configure the destination provider and connection settings |
| **Flags Tab** | Select global msdeploy flags (-xml, -allowUntrusted, -whatIf, -verbose) |
| **Rules Tab** | Configure deployment rules (DoNotDelete, AppPool, FilePath) |
| **Enable Links Tab** | Select link extensions to enable (AppPool, Content, Certificate) |
| **Disable Links Tab** | Select link extensions to disable |
| **Action Panel** | Save/load configurations, refresh site lists |
| **Command Preview** | Real-time display of the generated msdeploy command |
| **Activity Log** | Shows command execution output and errors |

## Configuration Sections

### Global Settings

#### Verb Selection

Select the msdeploy operation to perform:

| Verb | Description | Use Case |
|------|-------------|----------|
| `sync` | Synchronize source to destination | Standard migration/deployment |
| `dump` | Display provider data without changes | Inspect configuration |
| `delete` | Remove provider data | Clean up resources |
| `getDependencies` | Show dependencies | Analyze dependencies |
| `backup` | Create backup package | Backup before changes |
| `restore` | Restore from backup | Recover from backup |

**Default**: `sync` (most common for migrations)

### Source Configuration

#### Provider Types

Select the type of source content:

| Provider | Description | Main Value |
|----------|-------------|------------|
| `appHostConfig` | IIS site configuration | Site name from dropdown |
| `iisApp` | IIS application | Application path (e.g., /MyApp) |
| `contentPath` | Folder with content | Full folder path |
| `package` | Web Deploy package | Package file path (.zip) |
| `dirPath` | Directory | Full directory path |
| `filePath` | Single file | Full file path |

#### Connection Settings

Configure how to connect to the source:

- **IP Address/Computer Name**: Target machine (leave blank for local)
- **Authentication Type**: 
  - `NTLM` (default for Windows auth)
  - `Basic` (username/password)
  - `Negotiate` (auto-negotiate)
- **Username**: Authentication username (if remote)
- **Password**: Authentication password (if remote)

#### Site Selection

For `appHostConfig` provider:
- **Site Dropdown**: Auto-populated with IIS sites from the source server
- **Refresh Button**: Reload the site list

### Destination Configuration

Identical structure to source configuration, but with an additional `auto` provider option:

| Provider | Description | Main Value |
|----------|-------------|------------|
| `auto` | Auto-detect destination type | Optional value |
| *(others)* | Same as source | Same as source |

> **Note**: The `auto` provider is only available for destination and allows msdeploy to automatically determine the best provider type.

### Advanced Settings Tabs

#### Global Flags Tab

Select global msdeploy command-line flags:

| Flag | Description | When to Use |
|------|-------------|-------------|
| `-xml` | Output results in XML format | For programmatic parsing |
| `-allowUntrusted` | Allow untrusted SSL certificates | Self-signed certificates |
| `-whatIf` | Dry-run mode (no changes) | Test before actual migration |
| `-verbose` | Show detailed output | Troubleshooting |

> **Tip**: Always use `-whatIf` first to preview changes before executing actual migrations.

#### Deployment Rules Tab

Control what gets deployed or preserved:

| Rule | Description |
|------|-------------|
| `enableRule:DoNotDelete` | Prevent deletion of existing content |
| `enableRule:DoNotDeleteRule` | Prevent deletion based on rules |
| `disableRule:AppPool` | Don't synchronize application pools |
| `disableRule:FilePath` | Exclude file path synchronization |

#### Enable Link Extensions Tab

Enable link extensions for dependency synchronization:

| Link Extension | Description |
|----------------|-------------|
| `enableLink:AppPoolExtension` | Synchronize application pool extensions |
| `enableLink:ContentExtension` | Synchronize content extensions |
| `enableLink:CertificateExtension` | Synchronize SSL certificates |

#### Disable Link Extensions Tab

Disable specific link extensions:

| Link Extension | Description |
|----------------|-------------|
| `disableLink:AppPoolExtension` | Don't sync application pool extensions |
| `disableLink:ContentExtension` | Don't sync content extensions |
| `disableLink:CertificateExtension` | Don't sync SSL certificates |

## Usage Guide

### Step-by-Step: Basic Migration

1. **Launch the GUI**
   ```powershell
   .\gui-migrate.ps1
   ```

2. **Select Verb**
   - Choose `sync` from the verb dropdown

3. **Configure Source**
   - Provider: Select `appHostConfig`
   - Site: Choose your source site from the dropdown
   - Connection: Leave blank for local, or enter remote server details

4. **Configure Destination**
   - Provider: Select `appHostConfig` or `auto`
   - Connection: Enter destination server IP, username, and password
   - Authentication: Choose `NTLM` or `Basic`

5. **Set Flags** (Optional)
   - Check `-whatIf` for dry-run
   - Check `-verbose` for detailed output
   - Check `-allowUntrusted` if using self-signed certificates

6. **Review Command**
   - Check the "Command Preview" section
   - Verify all parameters are correct

7. **Execute**
   - Click "Execute Command" button
   - Monitor the Activity Log for output
   - Review the log file created in `site-logs/`

### Step-by-Step: Using Configuration Files

#### Save Configuration

1. Configure your source, destination, and all settings
2. Click "Save Configuration" button
3. Choose a location and filename (e.g., `prod-migration.xml`)
4. Configuration is saved as XML

#### Load Configuration

1. Click "Load Configuration" button
2. Select a previously saved configuration file
3. All settings are restored from the file
4. Review and adjust if needed before executing

## Command Preview and Execution

### Understanding the Command Preview

The command preview shows the exact msdeploy command that will be executed:

```powershell
& "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe" 
  -verb:sync 
  -source:appHostConfig="MySite",computerName=192.168.1.50,userName=admin,password=***,authtype=NTLM 
  -dest:appHostConfig="MySite",computerName=192.168.1.100,userName=admin,password=***,authtype=NTLM 
  -allowUntrusted 
  -verbose
```

### Execution Options

| Button | Action |
|--------|--------|
| **Execute Command** | Run the command immediately and display output |
| **Copy Command** | Copy the command to clipboard for manual execution |

### Activity Log

The activity log shows:
- Command execution start time
- Real-time output from msdeploy
- Success or error messages
- Completion status
- Log file location

All executions are also logged to: `site-logs/gui-msdeploy-YYYYMMDD-HHMMSS.log`

## State Management

### Auto-Save Feature

The GUI automatically saves your current state when you:
- Change any configuration setting
- Close the application

### State File Location

Configuration state is saved to: `gui-state.xml` in the script root directory

### What's Saved

- Selected verb
- Source provider and connection details
- Destination provider and connection details
- Selected flags, rules, and link extensions
- Window size and position (if implemented)

### Passwords

> **Security Note**: Passwords are saved in the state file. Ensure appropriate file system permissions on `gui-state.xml`.

## Common Scenarios

### Scenario 1: Local Site to Remote Server

**Goal**: Migrate a local IIS site to a remote server

```
Source:
- Provider: appHostConfig
- Site: Default Web Site
- Connection: (blank - local)

Destination:
- Provider: appHostConfig
- IP: 192.168.1.100
- Auth: NTLM
- Username: DOMAIN\admin
- Password: ********

Flags:
- -allowUntrusted
- -verbose
```

### Scenario 2: Remote Site Backup

**Goal**: Create a backup package of a remote site

```
Source:
- Provider: appHostConfig
- Site: Production Site
- IP: 192.168.1.50
- Auth: Basic
- Username: admin
- Password: ********

Destination:
- Provider: package
- Main Value: C:\Backups\prod-site-backup.zip
- Connection: (blank - local)

Verb: sync
Flags: -verbose
```

### Scenario 3: Dry-Run Migration Test

**Goal**: Test migration without making changes

```
(Configure as normal, but add:)

Flags:
- -whatIf
- -verbose

Result: Shows what would be done without making changes
```

### Scenario 4: Content-Only Migration

**Goal**: Migrate just the content files, not IIS configuration

```
Source:
- Provider: contentPath
- Main Value: C:\inetpub\wwwroot\MySite
- Connection: (blank - local)

Destination:
- Provider: contentPath
- Main Value: C:\inetpub\wwwroot\MySite
- IP: 192.168.1.100
- Auth: NTLM
- Username: admin
- Password: ********

Verb: sync
Flags: -verbose
```

### Scenario 5: Dump Site Configuration

**Goal**: View site configuration without making changes

```
Source:
- Provider: appHostConfig
- Site: MySite
- Connection: (blank - local)

Destination: (not needed for dump)

Verb: dump
Flags: -verbose
```

## Troubleshooting

### Common Issues

#### 1. "Microsoft Web Deploy V3 was not found"

**Cause**: msdeploy.exe is not installed or not in the expected location

**Solution**:
- Install Microsoft Web Deploy V3
- Verify installation at: `C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe`
- Download: https://www.microsoft.com/en-us/download/details.aspx?id=43717

#### 2. "This GUI must be launched from an elevated PowerShell session"

**Cause**: PowerShell is not running as Administrator

**Solution**:
- Close PowerShell
- Right-click PowerShell and select "Run as Administrator"
- Or use `start-gui.bat` which handles elevation automatically

#### 3. "Unable to load WebAdministration module"

**Cause**: IIS management tools are not installed

**Solution**:
```powershell
Add-WindowsFeature Web-Mgmt-Tools, Web-Scripting-Tools, Web-Mgmt-Console
```

#### 4. Site Dropdown is Empty

**Cause**: No IIS sites found or permission issues

**Solution**:
- Verify IIS is installed: `Get-Service W3SVC`
- Check that sites exist: `Get-ChildItem IIS:\Sites`
- Click the "Refresh" button next to the site dropdown
- Verify running as Administrator

#### 5. Authentication Failures

**Cause**: Incorrect credentials or authentication type

**Solution**:
- Verify username and password
- Try different authentication types (NTLM vs Basic)
- For NTLM, use format: `DOMAIN\username`
- For Basic, use: `username`
- Ensure the Web Management Service is running on remote servers
- Check firewall rules for msdeploy communication (port 8172 by default)

#### 6. "Command execution failed"

**Cause**: Various msdeploy errors

**Solution**:
- Check the Activity Log for specific error messages
- Review the log file in `site-logs/`
- Use `-whatIf` flag to test the command first
- Use `-verbose` flag for detailed output
- Verify both source and destination are accessible
- Ensure proper permissions on both sides

### Diagnostic Steps

1. **Test with -whatIf**
   ```
   Enable -whatIf flag and execute
   Review what would be changed
   ```

2. **Enable Verbose Logging**
   ```
   Enable -verbose flag
   Review detailed output in Activity Log
   ```

3. **Check Log Files**
   ```
   Navigate to site-logs/ directory
   Open the latest gui-msdeploy-*.log file
   Look for ERROR or WARNING entries
   ```

4. **Test Connectivity**
   ```powershell
   # Test remote server connectivity
   Test-NetConnection -ComputerName <IP> -Port 8172
   
   # Test WinRM (if using)
   Test-WSMan -ComputerName <IP>
   ```

5. **Verify Credentials**
   ```powershell
   # Test credentials manually
   $cred = Get-Credential
   Invoke-Command -ComputerName <IP> -Credential $cred -ScriptBlock { hostname }
   ```

## Advanced Features

### Module Architecture

The GUI is built on a modular architecture:

| Module | Purpose | Location |
|--------|---------|----------|
| `GuiLayout.ps1` | UI layout and form creation | `lib/GuiLayout.ps1` |
| `GuiHelpers.psm1` | Helper functions for GUI operations | `lib/GuiHelpers.psm1` |
| `GuiStateHelpers.psm1` | State save/load functionality | `lib/GuiStateHelpers.psm1` |

### Extending the GUI

To add custom functionality:

1. **Add New Providers**
   - Edit `$sourceProviders` and `$destProviders` arrays in `gui-migrate.ps1`
   - Add label mapping to `$providerMainValueLabel`

2. **Add New Flags**
   - Add to `$flags` array in `gui-migrate.ps1`
   - GUI will automatically include them in the Flags tab

3. **Add New Rules/Links**
   - Add to `$rules`, `$enableLinks`, or `$disableLinks` arrays
   - GUI will automatically include them in respective tabs

### Command-Line Integration

While the GUI is interactive, you can also use the underlying functions programmatically:

```powershell
# Import the modules
Import-Module .\lib\GuiHelpers.psm1
Import-Module .\lib\GuiStateHelpers.psm1

# Use helper functions in your own scripts
# (See module documentation for available functions)
```

### Batch Operations

For multiple migrations:

1. Configure the first migration in the GUI
2. Save the configuration to a file
3. Modify the XML file to create multiple variants
4. Load and execute each configuration

## Tips and Best Practices

### 🎯 Best Practices

1. **Always Test First**
   - Use `-whatIf` flag before any production migration
   - Test on non-production environments first

2. **Use Verbose Logging**
   - Enable `-verbose` flag for important migrations
   - Keep log files for audit trails

3. **Backup Before Migration**
   - Use the `backup` verb to create package backups
   - Store backups in a safe location

4. **Verify SSL Certificates**
   - Only use `-allowUntrusted` for self-signed certificates
   - Use proper SSL certificates in production

5. **Save Configurations**
   - Save common migration configurations for reuse
   - Document what each configuration does

6. **Monitor the Activity Log**
   - Watch for warnings and errors during execution
   - Review log files after migration

### ⚡ Performance Tips

1. Use `contentPath` provider for faster content-only migrations
2. Disable unnecessary link extensions to speed up sync
3. Use specific providers instead of `auto` when possible
4. Batch similar operations together

### 🔒 Security Considerations

1. **Credentials**: The GUI saves passwords in state files - secure these files appropriately
2. **Authentication**: Use NTLM when possible; Basic auth sends credentials less securely
3. **SSL/TLS**: Avoid `-allowUntrusted` in production; use valid certificates
4. **Logs**: Log files may contain sensitive information; secure the `site-logs/` directory
5. **Elevation**: Always run as Administrator; the GUI enforces this requirement

## Related Documentation

- [Main README](../README.md) - Complete project documentation
- [AGENTS.md](../AGENTS.md) - AI agent development guide
- [Migration Scripts](../source-scripts/) - Command-line migration scripts
- [Microsoft Web Deploy Documentation](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd569106(v=ws.10))

## Quick Reference

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Tab` | Navigate between fields |
| `Space` | Toggle checkboxes |
| `Enter` | Activate focused button |
| `Ctrl+C` | Copy (in Command Preview) |

### File Locations

| Item | Location |
|------|----------|
| Configuration State | `gui-state.xml` |
| Execution Logs | `site-logs/gui-msdeploy-*.log` |
| GUI Script | `gui-migrate.ps1` |
| Helper Modules | `lib/` directory |

### Default Values

| Setting | Default |
|---------|---------|
| Verb | `sync` |
| Source Provider | `appHostConfig` |
| Destination Provider | `auto` |
| Authentication | `NTLM` |
| Flags | None selected |

---

**Need Help?** 
- Check the [Troubleshooting](#troubleshooting) section
- Review log files in `site-logs/`
- See the main [README.md](../README.md) for more examples

**Version**: 1.0  
**Last Updated**: 2025-11-20  
**Maintainer**: IIS Migration Scripts Project
