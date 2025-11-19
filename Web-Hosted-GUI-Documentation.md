# Web-Hosted IIS Migration GUI

## Overview

The `web-hosted-gui-migrate.ps1` script is a self-contained PowerShell script that provides web-based distribution of the IIS Migration GUI. It automatically downloads and loads all required dependencies, making it easy to execute the GUI from any location without local file dependencies.

## Key Features

### ✅ Automatic Module Download

- Downloads all required `.psm1` modules from the same web URL
- Automatically determines base URL from script invocation
- Supports custom BaseUrl parameter for different hosting scenarios

### ✅ Smart Caching System

- Caches downloaded modules in `%TEMP%\IISMigrationGUI_Modules`
- Reduces download time on subsequent executions
- Supports cache bypass with `-ForceDownload` parameter

### ✅ Comprehensive Error Handling

- Handles network connectivity issues
- Manages module loading failures gracefully
- Provides detailed status reporting for debugging

### ✅ Complete Feature Parity

- All functionality from `gui-migrate.ps1` included
- Remote execution capabilities from `invoke-remote-gui.ps1`
- Full integration of all helper modules (GuiHelpers, GuiStateHelpers, MigrationHelper)

### ✅ Fallback Mechanisms

- Primary URL detection from script invocation
- Fallback to custom BaseUrl parameter
- Alternative module loading methods if direct execution fails

## Usage Instructions

### Basic Execution

```powershell
iex (iwr "https://example.com/web-hosted-gui-migrate.ps1")
```

### Advanced Usage

```powershell
# Custom module location
.\web-hosted-gui-migrate.ps1 -BaseUrl "https://myserver.com/modules"

# Disable caching
.\web-hosted-gui-migrate.ps1 -CacheModules:$false

# Force re-download
.\web-hosted-gui-migrate.ps1 -ForceDownload

# Custom URL with no caching
.\web-hosted-gui-migrate.ps1 -BaseUrl "https://backup-server.com/gui" -CacheModules:$false -ForceDownload
```

## Architecture

### Module Dependencies

The script automatically downloads and loads:

1. **GuiHelpers.psm1** - GUI helper functions
2. **GuiStateHelpers.psm1** - State management functions  
3. **MigrationHelper.psm1** - Migration utility functions

### URL Resolution

```md
Primary: Same URL as script (extracted from invocation)
Fallback: Custom BaseUrl parameter
Module URLs: {BaseUrl}/{ModuleName}.psm1
```

### Cache Location

```md
%TEMP%\IISMigrationGUI_Modules\
├── GuiHelpers.psm1
├── GuiStateHelpers.psm1
└── MigrationHelper.psm1
```

## Execution Flow

1. **Initialization**
   - Set up global variables and error handling
   - Parse command-line parameters

2. **URL Detection**
   - Extract base URL from script invocation
   - Fallback to BaseUrl parameter if needed

3. **Module Loading**
   - Check WebAdministration system module
   - Download and cache custom modules
   - Execute modules in memory
   - Verify successful loading

4. **GUI Initialization**
   - Load Windows Forms assemblies
   - Initialize all helper functions
   - Display success confirmation

5. **Remote Capabilities**
   - Enable remote GUI launching
   - Support WinRM, RDP, and local execution methods

## Error Scenarios

### Network Issues

- **Problem**: Cannot reach module URLs
- **Solution**: Use `-BaseUrl` to specify alternative location
- **Fallback**: Script continues with available modules if possible

### Module Load Failures

- **Problem**: Downloaded modules fail to execute
- **Solution**: Try `-ForceDownload` to re-download
- **Fallback**: Alternative execution methods attempted automatically

### Permission Issues

- **Problem**: Cannot create cache directory
- **Solution**: Run as administrator or disable caching with `-CacheModules:$false`
- **Note**: Administrator privileges required for IIS operations

### URL Resolution Failures

- **Problem**: Cannot determine script URL
- **Solution**: Explicitly specify `-BaseUrl` parameter
- **Example**: `-BaseUrl "https://your-server.com/gui-files"`

## Security Considerations

### Trust Model

- Modules downloaded from same origin as main script
- User-Agent header identifies the client
- HTTPS recommended for production deployment

### Execution Security

- All modules execute in current PowerShell context
- No temporary files left in system directories
- Cached modules can be cleared by deleting cache directory

## Remote Execution Features

### WinRM Method

- Direct PowerShell remoting to target server
- Executes GUI directly on remote machine
- Supports credential prompting

### RDP Method

- Launches Remote Desktop connection
- User manually runs GUI after connecting
- Useful for interactive server management

### Local Method

- Starts GUI on current machine
- Switches to WinRM if target is remote
- Fallback execution method

## Comparison with Local Version

| Feature | Local GUI | Web-Hosted GUI |
|---------|-----------|----------------|
| Setup Requirements | Manual file placement | None (web download) |
| Module Dependencies | Local .psm1 files | Auto-downloaded |
| Updates | Manual file replacement | Automatic on script update |
| Remote Execution | Separate script needed | Built-in functionality |
| Caching | N/A | Module caching system |
| URL Flexibility | N/A | Multiple URL resolution methods |

## Deployment Instructions

### Hosting Requirements

1. Web server accessible to target machines
2. Same-origin policy for modules (or CORS configuration)
3. HTTPS recommended for security
4. Proper MIME types for .psm1 files

### File Structure

```md
https://your-server.com/
├── web-hosted-gui-migrate.ps1
├── GuiHelpers.psm1
├── GuiStateHelpers.psm1
└── MigrationHelper.psm1
```

### Testing Deployment

```powershell
# Test basic connectivity
iwr "https://your-server.com/web-hosted-gui-migrate.ps1"

# Test module availability
iwr "https://your-server.com/GuiHelpers.psm1"

# Test full execution (dry run)
iex (iwr "https://your-server.com/web-hosted-gui-migrate.ps1") -WhatIf
```

## Troubleshooting

### Common Issues

1. **"Cannot determine base URL"**
   - Use explicit `-BaseUrl` parameter
   - Check URL format (include protocol)

2. **Module download failures**
   - Verify web server connectivity
   - Check MIME types on server
   - Try alternative BaseUrl

3. **Permission denied errors**
   - Run PowerShell as administrator
   - Check antivirus blocking
   - Verify IIS management tools installed

4. **GUI fails to start**
   - Check Windows Forms dependencies
   - Verify Microsoft Web Deploy V3 installed
   - Review execution policy settings

### Debug Mode

```powershell
# Enable verbose output
$VerbosePreference = "Continue"
iex (iwr "https://your-server.com/web-hosted-gui-migrate.ps1")
```

## Future Enhancements

- Support for module version checking
- Delta updates for large modules
- Integrated update notifications
- Enhanced error reporting with telemetry
- Support for module dependency chains
- Built-in configuration management

## Conclusion

The web-hosted GUI script provides a robust, self-contained solution for distributing the IIS Migration GUI across multiple servers without manual file management. Its comprehensive error handling, caching system, and remote execution capabilities make it suitable for enterprise deployments while maintaining simplicity for single-server use cases.
