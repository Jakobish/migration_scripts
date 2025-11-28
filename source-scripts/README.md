# RELOCATION WORKFLOW

1. Run export-acls-to-csv.ps1 on SOURCE.
2. Run migrate-websites.ps1 on SOURCE (in batches).
3. Run create-iis-users.ps1 on DESTINATION.
4. Run import-acls-from-csv.ps1 on DESTINATION.
5. Optionally run fix-ip.ps1 on DESTINATION.
