# Agent Rules Standard (AGENTS.md)

This file provides comprehensive guidance for all agents working with the IIS migration scripts repository.

## Project Context

This repository contains a suite of PowerShell scripts designed to facilitate the migration of IIS websites from a **Source** server to a **Destination** server.
- **Goal**: Automate the export of sites, application pools, and content from one server and import them onto another, preserving configurations and permissions.
- **Key Script**: `gui-migrate.ps1` is the main entry point, providing a GUI to drive the migration process.

## Coding Standards

To maintain code quality and prevent common PowerShell pitfalls:

- **No Aliases**: Always use full cmdlet names (e.g., `Where-Object` instead of `?`, `ForEach-Object` instead of `%`). This improves readability and prevents ambiguity.
- **PascalCase**: Use PascalCase for all variable names (e.g., `$SiteName`, `$DestinationServer`) and function names.
- **Syntax Checking**: Always run `.\check-syntax.ps1` after making changes to ensure no syntax errors were introduced.
- **Error Handling**: Use `Try/Catch` blocks for critical operations, especially those involving file I/O or remote connections.

## Critical Execution Requirements

- **msdeploy commands**: MUST be wrapped in `cmd.exe /c`. Direct execution in PowerShell often fails due to quoting issues.
- **Microsoft Web Deploy V3**: Required at `C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe`.
- **Administrator privileges**: All scripts require elevated permissions to access IIS configuration and system files.
- **PowerShell directives**: All scripts require `#Requires -RunAsAdministrator`.

## Architecture Overview

### Main Entry Point
- **gui-migrate.ps1**: The primary GUI tool that orchestrates the migration. It loads helper modules and manages the user interface.

### Helper Modules
- **GuiHelpers.psm1**: Contains UI-related helper functions (e.g., creating buttons, labels, text boxes).
- **GuiStateHelpers.psm1**: Manages the state of the GUI, including loading/saving configurations and handling event logic.

### Two-Tier Script Structure
- **source-scripts/**: Scripts executed on the **Source** server (e.g., to export sites, dump configuration).
- **destination-scripts/**: Scripts executed on the **Destination** server (e.g., to create users, import sites).

### Module Fallback Architecture
- Primary: `IISAdministration` module (preferred).
- Fallback: `WebAdministration` with edition checking.
- IISAdministration detection requires explicit command availability checks.
- Uses `Add-WindowsFeature` (not `Install-WindowsFeature`) for compatibility.

## Implementation Patterns & Known Issues

### Variable Naming Inconsistencies
- **$name vs $sitename**: Both variables used for same site - architectural debt that must be maintained.
- **Line 86 in migrate-websites.ps1**: Uses wrong variable - requires careful handling.
- **$DestinatoinServerIP vs $DestinationServerIP**: Parameter typo became part of public API - changing breaks compatibility.

### Application Pool Handling
- Application pool objects may return as arrays - always use `$pool[0]` extraction.
- ACL identity format: `$appPoolIdentity = "IIS APPPOOL\$pool"`.

### Logging & Error Handling
- **Dual logging**: `Tee-Object` for console + file simultaneously.
- **Error suppression**: `2>$null` for non-critical operations can hide failures.
- **msdeploy failures**: Don't throw PowerShell exceptions - check `$LASTEXITCODE`.
- **Log directories**: Auto-created - check `.\site-logs` if missing.

## Required Dependencies

- **Password generation**: `System.Web.Security.Membership` with `GeneratePassword(20, 4)`.
- **Windows user creation**: `net.exe user` commands (not PowerShell cmdlets).
- **ACL management**: msdeploy with specific `-enableLink` flags.

## ACL Management Requirements

### Required msdeploy Flags
```cmd
-enableLink:AppPoolExtension,ContentExtension,CertificateExtension
```

### Key Notes
- ACL sync failures are non-fatal - script continues but warnings suppressed.
- ACL management is centralized through msdeploy with specific flag combinations.

### Command Execution
- **WhatIf mode**: Only logs intended commands - actual execution still pending.
- **Batch processing**: Supports dry runs without actual migration.
- **Commented-out blocks**: ACL sync, retry logic suggest incomplete architectural decisions.

## Approved Verbs

The following list of verbs is provided for reference to ensure compliance with PowerShell's approved verb list (to avoid `AvoidUnapprovedVerbs` warnings).

Verb        AliasPrefix Group          Description
----        ----------- -----          -----------
Add         a           Common         Adds a resource to a container, or attaches an i…
Clear       cl          Common         Removes all the resources from a container but d…
Close       cs          Common         Changes the state of a resource to make it inacc…
Copy        cp          Common         Copies a resource to another name or to another …
Enter       et          Common         Specifies an action that allows the user to move…
Exit        ex          Common         Sets the current environment or context to the m…
Find        fd          Common         Looks for an object in a container that is unkno…
Format      f           Common         Arranges objects in a specified form or layout
Get         g           Common         Specifies an action that retrieves a resource
Hide        h           Common         Makes a resource undetectable
Join        j           Common         Combines resources into one resource
Lock        lk          Common         Secures a resource
Move        m           Common         Moves a resource from one location to another
New         n           Common         Creates a resource
Open        op          Common         Changes the state of a resource to make it acces…
Optimize    om          Common         Increases the effectiveness of a resource
Push        pu          Common         Adds an item to the top of a stack
Pop         pop         Common         Removes an item from the top of a stack
Redo        re          Common         Resets a resource to the state that was undone
Remove      r           Common         Deletes a resource from a container
Rename      rn          Common         Changes the name of a resource
Reset       rs          Common         Sets a resource back to its original state
Resize      rz          Common         Changes the size of a resource
Search      sr          Common         Creates a reference to a resource in a container
Select      sc          Common         Locates a resource in a container
Set         s           Common         Replaces data on an existing resource or creates…
Show        sh          Common         Makes a resource visible to the user
Skip        sk          Common         Bypasses one or more resources or points in a se…
Split       sl          Common         Separates parts of a resource
Step        st          Common         Moves to the next point or resource in a sequence
Switch      sw          Common         Specifies an action that alternates between two …
Undo        un          Common         Sets a resource to its previous state
Unlock      uk          Common         Releases a resource that was locked
Watch       wc          Common         Continually inspects or monitors a resource for …
Connect     cc          Communications Creates a link between a source and a destination
Disconnect  dc          Communications Breaks the link between a source and a destinati…
Read        rd          Communications Acquires information from a source
Receive     rc          Communications Accepts information sent from a source
Send        sd          Communications Delivers information to a destination
Write       wr          Communications Adds information to a target
Backup      ba          Data           Stores data by replicating it
Checkpoint  ch          Data           Creates a snapshot of the current state of the d…
Compare     cr          Data           Evaluates the data from one resource against the…
Compress    cm          Data           Compacts the data of a resource
Convert     cv          Data           Changes the data from one representation to anot…
ConvertFrom cf          Data           Converts one primary type of input (the cmdlet n…
ConvertTo   ct          Data           Converts from one or more types of input to a pr…
Dismount    dm          Data           Detaches a named entity from a location
Edit        ed          Data           Modifies existing data by adding or removing con…
Expand      en          Data           Restores the data of a resource that has been co…
Export      ep          Data           Encapsulates the primary input into a persistent…
Group       gp          Data           Arranges or associates one or more resources
Import      ip          Data           Creates a resource from data that is stored in a…
Initialize  in          Data           Prepares a resource for use, and sets it to a de…
Limit       l           Data           Applies constraints to a resource
Merge       mg          Data           Creates a single resource from multiple resources
Mount       mt          Data           Attaches a named entity to a location
Out         o           Data           Sends data out of the environment
Publish     pb          Data           Makes a resource available to others
Restore     rr          Data           Sets a resource to a predefined state, such as a…
Save        sv          Data           Preserves data to avoid loss
Sync        sy          Data           Assures that two or more resources are in the sa…
Unpublish   ub          Data           Makes a resource unavailable to others
Update      ud          Data           Brings a resource up-to-date to maintain its sta…
Debug       db          Diagnostic     Examines a resource to diagnose operational prob…
Measure     ms          Diagnostic     Identifies resources that are consumed by a spec…
Ping        pi          Diagnostic     Use the Test verb
Repair      rp          Diagnostic     Restores a resource to a usable condition
Resolve     rv          Diagnostic     Maps a shorthand representation of a resource to…
Test        t           Diagnostic     Verifies the operation or consistency of a resou…
Trace       tr          Diagnostic     Tracks the activities of a resource
Approve     ap          Lifecycle      Confirms or agrees to the status of a resource o…
Assert      as          Lifecycle      Affirms the state of a resource
Build       bd          Lifecycle      Creates an artifact (usually a binary or documen…
Complete    cmp         Lifecycle      Concludes an operation
Confirm     cn          Lifecycle      Acknowledges, verifies, or validates the state o…
Deny        dn          Lifecycle      Refuses, objects, blocks, or opposes the state o…
Deploy      dp          Lifecycle      Sends an application, website, or solution to a …
Disable     d           Lifecycle      Configures a resource to an unavailable or inact…
Enable      e           Lifecycle      Configures a resource to an available or active …
Install     is          Lifecycle      Places a resource in a location, and optionally …
Invoke      i           Lifecycle      Performs an action, such as running a command or…
Register    rg          Lifecycle      Creates an entry for a resource in a repository …
Request     rq          Lifecycle      Asks for a resource or asks for permissions
Restart     rt          Lifecycle      Stops an operation and then starts it again
Resume      ru          Lifecycle      Starts an operation that has been suspended
Start       sa          Lifecycle      Initiates an operation
Stop        sp          Lifecycle      Discontinues an activity
Submit      sb          Lifecycle      Presents a resource for approval
Suspend     ss          Lifecycle      Pauses an activity
Uninstall   us          Lifecycle      Removes a resource from an indicated location
Unregister  ur          Lifecycle      Removes the entry for a resource from a reposito…
Wait        w           Lifecycle      Pauses an operation until a specified event occu…
Use         u           Other          Uses or includes a resource to do something
Block       bl          Security       Restricts access to a resource
Grant       gr          Security       Allows access to a resource
Protect     pt          Security       Safeguards a resource from attack or loss
Revoke      rk          Security       Specifies an action that does not allow access t…
Unblock     ul          Security       Removes restrictions to a resource
Unprotect   up          Security       Removes safeguards from a resource that were add…
