# Agent Rules Standard (AGENTS.md)

This file provides comprehensive guidance for all agents working with the IIS migration scripts repository.

## Critical Execution Requirements

- **msdeploy commands**: MUST be wrapped in `cmd.exe /c` (direct execution fails)
- **Microsoft Web Deploy V3**: Required at `C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe`
- **Administrator privileges**: All scripts require elevated permissions
- **PowerShell directives**: All scripts require `#Requires -RunAsAdministrator`

## Architecture Overview

### Two-Tier Script Structure

- **source-scripts/**: Scripts for exporting/migrating FROM current server
- **destination-scripts/**: Scripts for setup ON target server

### Module Fallback Architecture

- Primary: `IISAdministration` module
- Fallback: `WebAdministration` with edition checking
- IISAdministration detection requires explicit command availability checks
- Uses `Add-WindowsFeature` (not `Install-WindowsFeature`)

## Implementation Patterns & Known Issues

### Variable Naming Inconsistencies

- **$name vs $sitename**: Both variables used for same site - architectural debt that must be maintained
- **Line 86 in migrate-websites.ps1**: Uses wrong variable - requires careful handling
- **$DestinatoinServerIP vs $DestinationServerIP**: Parameter typo became part of public API - changing breaks compatibility

### Application Pool Handling

- Application pool objects may return as arrays - always use `$pool[0]` extraction
- ACL identity format: `$appPoolIdentity = "IIS APPPOOL\$pool"`

### Logging & Error Handling

- **Dual logging**: `Tee-Object` for console + file simultaneously
- **Error suppression**: `2>$null` for non-critical operations can hide failures
- **msdeploy failures**: Don't throw PowerShell exceptions - check `$LASTEXITCODE`
- **Log directories**: Auto-created - check `.\site-logs` if missing

## Required Dependencies

- **Password generation**: `System.Web.Security.Membership` with `GeneratePassword(20, 4)`
- **Windows user creation**: `net.exe user` commands (not PowerShell cmdlets)
- **ACL management**: msdeploy with specific `-enableLink` flags

## ACL Management Requirements

### Required msdeploy Flags

```cmd
-enableLink:AppPoolExtension,ContentExtension,CertificateExtension
```

### Key Notes

- ACL sync failures are non-fatal - script continues but warnings suppressed
- ACL management is centralized through msdeploy with specific flag combinations

### Command Execution

- **WhatIf mode**: Only logs intended commands - actual execution still pending
- **Batch processing**: Supports dry runs without actual migration
- **Commented-out blocks**: ACL sync, retry logic suggest incomplete architectural decisions
