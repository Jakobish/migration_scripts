# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Critical Execution Requirements

- All scripts require IIS WebAdministration module (`Import-Module WebAdministration`)
- Microsoft Web Deploy V3 must be installed at `C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe`
- Scripts must run with Administrator privileges for IIS operations
- msdeploy commands must be wrapped in `cmd.exe /c` (not executed directly in PowerShell)

## Script Architecture

- `source-scripts/` - Migration scripts that export/migrate FROM this server
- `destination-scripts/` - Setup scripts that run ON destination server
- GUI scripts (`gui-migrate-websites.ps1`) provide interactive workflows
- CLI scripts (`migrate-websites.ps1`) support batch processing with parameters

## Critical Implementation Patterns

- Variable naming inconsistency: `$name` vs `$sitename` - both used for same site variable
- Application pool objects may return as arrays - extract with `$pool[0]` check
- ACL commands use `$appPoolIdentity = "IIS APPPOOL\$pool"` format
- Logs use dual output: `Tee-Object` for console + file simultaneously
- Error suppression with `2>$null` for non-critical operations

## Required Dependencies

- `System.Web.Security.Membership` for password generation (`GeneratePassword`)
- IIS application pool access via `Get-WebConfigurationProperty`
- Windows user creation via `net user` commands
- Windows ACL management via msdeploy setAcl operations

## Execution Commands

- Run GUI: `powershell -ExecutionPolicy Bypass .\source-scripts\gui-migrate-websites.ps1`
- Run batch migration: `powershell -ExecutionPolicy Bypass .\source-scripts\migrate-websites.ps1 -DestinationServer "SERVER" -DestUsername "user"`
- Setup destination: `powershell -ExecutionPolicy Bypass .\destination-scripts\create-iis-users.ps1`

## Non-Obvious Gotchas

- Site binding IP replacement uses regex `"\d{1,3}(\.\d{1,3}){3}"` for auto-updating server references
- SecureString parameters cannot be passed via command line - prompt user or use alternative
- ACL sync requires `-enableLink:AppPoolExtension,ContentExtension,CertificateExtension` flags
- Log directories auto-created if missing (`.`, `.\site-logs`)
- Batch processing supports WhatIf mode for dry runs without actual migration
