# Copilot instructions for migration_scripts

This repository is a collection of small, single-purpose Windows migration scripts (PowerShell + Batch) used to relocate IIS sites and ACLs between servers. Keep guidance short and actionable so an AI agent can be immediately productive.

- **Big picture:** these scripts automate a multi-step relocation workflow (see `README.txt`):
  1. `export-acls.bat` runs on the SOURCE server to export ACLs with `icacls`.
 2. `migrate-websites.ps1` runs on the SOURCE to sync IIS site configuration (uses `msdeploy`).
 3. `create-iis-users.ps1` runs on the DESTINATION to create local IIS user accounts and assign them to app pools.
 4. `import-acls.bat` runs on the DESTINATION to restore previously exported ACLs.
 5. `fix-ip.ps1` optionally adjusts IPs inside `applicationHost.config` (creates a timestamped backup).

- **Key integration points & external tools:**
  - `msdeploy` (Web Deploy) — used by `migrate-websites.ps1`. Credentials are currently placeholders in the script; do not hardcode secrets.
  - `icacls` — used by `export-acls.bat` / `import-acls.bat` to save/restore ACLs.
  - Windows `net user`, PowerShell `WebAdministration` module — used by `create-iis-users.ps1`.

- **Environment expectations:**
  - These scripts are designed to run on Windows servers with Administrator privileges.
  - Paths in scripts are absolute (e.g., `D:\Domains`, `D:\ACL-Export`, `C:\logs`) — agents should not change these unless guided by a user or adding configurability.

- **Developer workflows / common commands:**
  - Run migration script in batches (example):
    - `powershell -ExecutionPolicy Bypass -File migrate-websites.ps1 -StartIndex 0 -Batch 10 -WhatIf`
  - Create IIS users on destination (run as admin):
    - `powershell -ExecutionPolicy Bypass -File create-iis-users.ps1`
  - Export ACLs on source (run as admin):
    - `export-acls.bat`
  - Import ACLs on destination (run as admin):
    - `import-acls.bat`
  - Replace IPs with backup (run on destination; note backup file naming):
    - `powershell -ExecutionPolicy Bypass -File fix-ip.ps1`

- **Project-specific patterns & conventions:**
  - Small, focused scripts (one responsibility each) — prefer editing or adding a new script over consolidating multiple responsibilities into a single script unless the change justifies it.
  - Scripts write logs or backups by default (`migrate-websites.ps1` writes `C:\logs\deploy_<site>_<ts>.txt`, `fix-ip.ps1` creates a `.bak_<ts>` backup). Preserve this behavior when making changes.
  - Credentials and remote targets are *not* stored in a separate config file — `migrate-websites.ps1` includes an inline `-dest:...,userName=...,password=...` placeholder. When adding features, prefer parameterizing credentials and avoiding plaintext secrets.

- **Safety and review guidance for AI edits:**
  - Never execute these scripts in the agent runtime. Editing or suggesting changes is fine; do not run them.
  - When proposing changes that touch ACLs, user accounts, or IIS config paths, include a short rationale, a simple manual verification checklist, and a dry-run option where practical (e.g., keep or extend `-WhatIf` behavior).

- **Files to reference when making changes:**
  - `README.txt` — canonical workflow order and quick steps.
  - `migrate-websites.ps1` — shows batch processing, `msdeploy` usage, and logging.
  - `create-iis-users.ps1` — shows how app-pool identities are set and username/password generation.
  - `export-acls.bat` / `import-acls.bat` — show `icacls` usage and export/import patterns.
  - `fix-ip.ps1` — shows conservative change-with-backup pattern for config edits.

- **What to do first when you start working here:**
  1. Read `README.txt` to understand the intended run order. 2. Open `migrate-websites.ps1` and `create-iis-users.ps1` for concrete examples of patterns to follow. 3. If adding functionality that runs on servers, add parameters for credentials and a `-WhatIf`/dry-run mode.

If anything here is unclear or you'd like me to expand a section (for example, add sample parameterization for `migrate-websites.ps1`), tell me which area to expand. 
