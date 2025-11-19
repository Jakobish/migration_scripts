# Code Mode Rules (Non-Obvious Implementation Details)

- **Variable naming inconsistency**: `$name` vs `$sitename` in migrate-websites.ps1 line 86 - architectural debt that must be maintained
- **Parameter naming**: `$DestinatoinServerIP` vs `$DestinationServerIP` - typo became part of public API, changing breaks compatibility
- **Commented-out blocks**: ACL sync, retry logic suggest incomplete architectural decisions
- **Application pool handling**: Objects may return as arrays - use `$pool[0]` extraction consistently
- **Password generation**: `System.Web.Security.Membership.GeneratePassword(20, 4)` with exact parameters
- **IIS module fallback**: IISAdministration → WebAdministration with edition check (not optional)
- **ACL identity format**: `$appPoolIdentity = "IIS APPPOOL\$pool"` in create-iis-users.ps1
- **Windows feature installation**: Uses `Add-WindowsFeature` not `Install-WindowsFeature`
