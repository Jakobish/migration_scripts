# Project Debug Rules (Non-Obvious Only)

## Hidden Log Locations

- Main migration log: `.\migrate-websites.log` (created in script directory)
- Site-specific logs: `.\site-logs\{site-name}-{timestamp}.log` (auto-created directory)
- GUI migration logs: `.\migration-{siteName}-{timestamp}.log`

## Error Handling Gotchas

- Errors caught in try/catch are logged but execution continues with next site
- msdeploy failures don't throw PowerShell exceptions - check exit codes
- Silent failures occur if msdeploy.exe path is incorrect or missing

## Debugging msdeploy Commands

- WhatIf mode shows commands without execution (line 78-87 in migrate-websites.ps1)
- Use `-WhatIf` parameter for batch script to preview operations
- Commands must be wrapped in `cmd.exe /c` - direct PowerShell execution fails

## Privileges Required

- Administrator rights required for all IIS operations
- Scripts fail silently if not run as admin
- WebAdministration module requires elevated permissions

## Network Debugging

- Site binding IP replacement uses regex: `"\d{1,3}(\.\d{1,3}){3}"`
- Check this regex pattern when debugging binding updates
- Destination server must be accessible via network (test with ping first)

## Execution Policy Issues

- Use `-ExecutionPolicy Bypass` to avoid policy restrictions
- Standard PowerShell execution policies block unsigned scripts
