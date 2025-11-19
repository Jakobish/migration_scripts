# Debug Mode Rules (Non-Obvious Troubleshooting Context)

- **Dual logging pattern**: `Tee-Object` outputs to both console and files - check `.\site-logs` directories
- **Silent failures**: `2>$null` suppresses errors for non-critical operations - may hide actual issues
- **msdeploy error handling**: Commands don't throw PowerShell exceptions - always check `$LASTEXITCODE`
- **Non-fatal ACL sync failures**: Script continues but warnings are suppressed - examine logs manually
- **WhatIf mode behavior**: Only logs intended commands - actual migration not performed
- **Hebrew comments**: Server-Setup-Util.ps1 contains multilingual comments (פשוט, אפשרות, משאיר)
- **Windows feature commands**: Uses `Add-WindowsFeature` not `Install-WindowsFeature` for IIS installation
- **Log directory creation**: Auto-created during execution - check `.\site-logs` if logs appear missing
- **Batch processing**: Supports dry runs for testing without actual migratio
