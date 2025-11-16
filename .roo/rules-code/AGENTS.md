# Project Coding Rules (Non-Obvious Only)

## Variable Inconsistencies

- `$name` and `$sitename` are used interchangeably for the same site variable (line 32, 44, 46, 97 in migrate-websites.ps1)
- Always check which variable name is used in the specific context

## Critical Array Extraction

- Application pool objects may return as arrays - always extract with `$pool[0]` check (line 37-39 in migrate-websites.ps1)
- This pattern is mandatory, not optional, for robust script operation

## Dual Logging Pattern

- All operations use `Tee-Object` for simultaneous console and file output (line 24, 28, 46, 91, 94)
- Never use `Write-Host` or `Out-File` alone when capturing execution logs
- This enables real-time monitoring during long migrations

## Error Suppression Convention

- Use `2>$null` for non-critical operations to prevent noisy output (line 8 in create-iis-users.ps1)
- This maintains clean console output while preserving error tracking

## msdeploy Command Construction

- Always wrap msdeploy commands in `cmd.exe /c` (not executed directly in PowerShell)
- Command arrays must be joined with spaces and proper quoting
- Quote handling is critical: use backtick escaping for nested quotes
