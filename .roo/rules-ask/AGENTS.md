# Ask Mode Rules (Non-Obvious Documentation & Usage Context)

- **Script architecture**: `source-scripts/` export/migrate FROM current server, `destination-scripts/` run ON target server
- **GUI vs CLI workflows**: `gui-migrate-websites.ps1` provides interactive workflows, CLI scripts support batch processing
- **Documentation gaps**: `MsDeployHelp.txt` contains command-line examples not found in PowerShell scripts
- **Utility functions**: Server-Setup-Util.ps1 is a comprehensive menu-driven utility, not just basic setup scripts
- **ACL management requirements**: msdeploy with specific `-enableLink:AppPoolExtension,ContentExtension,CertificateExtension` flags
- **Parameter naming impact**: `$DestinatoinServerIP` typo affects command-line usage patterns and backward compatibility
- **Multilingual considerations**: Hebrew comments in Server-Setup-Util.ps1 indicate internationalization requirements
- **Interactive documentation**: Reference both script functionality and command-line examples for comprehensive help
- **WhatIf mode**: Supports dry-run capabilities for testing without actual migration
- **Log analysis**: Both console output and file logs (`.\site-logs`) contain important debugging information
