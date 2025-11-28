
# --- Configuration Variables ---
$SourceServer = "1.1.1.1"
$User = "administrator"
$Password = "YourAdminPassword" # IMPORTANT: In production, use Get-Credential or a secure secret store
$AuthType = "NTLM" 
$LocalOutputFile = ".\SiteInventory.xml"
$MSDeployPath = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe" 
# Command to run remotely: list all sites and output in XML
$AppCmdCommand = "%windir%\system32\inetsrv\appcmd.exe list site" 

Write-Host "--- 1. Fetching Site Inventory from $SourceServer ---"

# Use runCommand as the source provider to execute AppCmd remotely and sync the output to a local file
& $MSDeployPath -verb:dump `
    -source:runCommand="$AppCmdCommand",computerName="$SourceServer",userName="$User",password="$Password",authType="$AuthType" `
    -dest:filePath="$LocalOutputFile" `
    -allowUntrusted -xml

Write-Host "Inventory saved to $LocalOutputFile"

# --- Load and Parse the XML ---
[xml]$SiteListXml = Get-Content $LocalOutputFile
$SiteNames = @()

# Parse the XML structure returned by AppCmd.exe
$SiteListXml.selectnodes("//SITE") | ForEach-Object {
    $SiteName = $_.Attributes | Where-Object { $_.Name -eq "name" } | Select-Object -ExpandProperty Value
    if ($SiteName -and $SiteName -ne "Default Web Site") {
        $SiteNames += $SiteName
    }
}

Write-Host "Found $($SiteNames.Count) sites to migrate: $($SiteNames -join ', ')"
# --- Destination Details (The New Server, running this script) ---


Write-Host "--- 2. Starting MSDeploy PUSH/PULL Sync Loop ---"

foreach ($SiteName in $SiteNames) {
    Write-Host "--------------------------------------------------"
    Write-Host "Migrating site: $SiteName"

       
    $MSDeployCommand = "$MSDeployPath -verb:sync `
        -preSync:runCommand=`"$PreSyncCommand`" `
        -postSync:runCommand=`"$PostSyncCommand`" `
        -source:iisApp=`"$SiteName`",computerName=`"$SourceServer`",userName=`"$User`",password=`"$SourcePassword`",authType=`"$AuthType`" `
        -dest:auto `
        -enableLink:AppPoolExtension `      # Ensures App Pool configuration is migrated/updated
        -enableLink:ContentExtension `       # Explicitly link content (though iisApp often covers it)
        -allowUntrusted `
        -whatif"                               # Use -whatif for safe simulation before execution
    
    Write-Host "Executing MSDeploy PULL for $SiteName..."
    
    # If the site doesn't exist on the destination, MSDeploy will try to create it.
    Invoke-Expression $MSDeployCommand

    Write-Host "PostSync: Operation completed for $SiteName."
}
