# Project Architecture Rules (Non-Obvious Only)

## Migration Model

- Push-based migration architecture: source server scripts initiate operations on destination
- No pull mechanism exists - destination server is passive recipient
- Two-phase process: migration scripts on source + setup scripts on destination

## Hard External Dependencies

- msdeploy.exe hardcoded at `C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe`
- No fallback or path discovery - scripts fail if this specific path is wrong
- IIS WebAdministration module is mandatory - no alternative IIS management approach

## Windows-Lock Architecture

- Scripts assume Windows-only environment with IIS
- No abstraction layer for cross-platform compatibility
- Batch files (.bat) cannot be easily replaced with shell scripts

## Error Handling Strategy

- Continue-on-error model for batch operations (one site failure doesn't stop batch)
- No rollback mechanism exists for failed migrations
- Silent failures possible with msdeploy path issues or privilege problems

## Security Model

- ACL sync happens separately from main migration (two-step process)
- Application pool identity format: `"IIS APPPOOL\$pool"` is hardcoded
- No support for custom identity types beyond IIS APPPOOL format

## Two-UI Paradigm

- GUI (`gui-migrate-websites.ps1`) and CLI (`migrate-websites.ps1`) have identical backend
- No shared library between them - duplicate logic instead of abstraction
- Different parameter handling approaches but same msdeploy command generation

## Batch Processing Architecture

- Supports WhatIf mode for safety testing
- Array handling with `$pool[0]` suggests inconsistent API responses
- No progress tracking or resume capability for interrupted batches

## No State Management

- Stateless migration design - each site migrated independently
- Log files created per-site and per-batch but no central state tracking
- No migration history or rollback state stored
