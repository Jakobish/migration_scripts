
Get-ChildItem "d:\domains" -Recurse | Where-Object { $_.PsIsContainer } | ForEach-Object {
    $Path = $_.FullName
    # Exclude inherited rights from the report
    (Get-Acl $Path).Access | Where-Object { !$_.IsInherited } | Select-Object `
    @{n = 'Path'; e = { $Path } }, IdentityReference, AccessControlType, `
        InheritanceFlags, PropagationFlags, FileSystemRights
} | Export-CSV ".\Permissions.csv"
