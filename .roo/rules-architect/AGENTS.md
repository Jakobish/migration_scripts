# Architect Mode Rules (Non-Obvious Architectural Constraints)

- **Two-tier architecture**: `source-scripts/` for migration FROM server, `destination-scripts/` for setup ON target server
- **Module fallback architecture**: IISAdministration → WebAdministration with edition checking (not optional)
- **ACL management**: Centralized through msdeploy with specific flag combinations for permissions
- **Variable naming inconsistency**: `$name` vs `$sitename` - architectural debt that must be maintained for compatibility
- **Commented-out code blocks**: ACL sync, retry logic suggest incomplete architectural decisions awaiting resolution
- **Parameter naming**: `$DestinatoinServerIP` typo became part of public API - changing breaks backward compatibility
- **Hebrew comments**: Server-Setup-Util.ps1 contains multilingual comments indicating i18n requirements not yet implemented
- **PowerShell requirements**: All scripts require `#Requires -RunAsAdministrator` directive for proper execution
- **Command execution**: msdeploy commands MUST be wrapped in `cmd.exe /c` for proper functionality
- **Log architecture**: Dual logging with `Tee-Object` to both console and file systems (`.\site-logs`)
- **Error handling**: msdeploy failures don't throw PowerShell exceptions - require explicit `$LASTEXITCODE` checking
- **Batch processing**: Supports WhatIf mode for dry runs without actual migration
