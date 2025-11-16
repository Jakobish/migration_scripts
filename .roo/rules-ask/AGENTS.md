# Project Documentation Rules (Non-Obvious Only)

## Misleading Folder Organization

- `source-scripts/` contains migration scripts that run ON the source server (counterintuitive name)
- `destination-scripts/` contains setup scripts that run ON the destination server (after migration)
- This split indicates a push-migration model, not a pull-model

## Hidden Windows Dependencies

- All scripts are Windows-only and require IIS (not cross-platform)
- Batch files (.bat) are Windows-specific and won't work on Linux/Mac
- PowerShell scripts require Windows PowerShell or PowerShell Core
- No Docker or containerization support exists

## Two Migration Approaches

- GUI workflow (`gui-migrate-websites.ps1`) - interactive, single-site migrations
- CLI workflow (`migrate-websites.ps1`) - automated, batch processing
- Both use different UI paradigms but similar msdeploy backend logic

## Missing Package Management

- No package.json, requirements.txt, or equivalent dependency management
- External dependencies must be manually installed (IIS WebAdministration, msdeploy)
- No automated dependency checking in scripts

## Sparse Documentation

- Only one README.txt exists with minimal guidance
- No inline PowerShell comment-based help (Get-Help won't work)
- Script documentation is primarily in GUI script header comments only

## Deployment Model Confusion

- Scripts assume pre-existing destination server setup
- No automation for initial IIS/Web Deploy installation on destination
- ACL management suggests granular permission control but no explanation of why
