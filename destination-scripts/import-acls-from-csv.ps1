
$par = Import-Csv -Path ".\Permissions.csv"
foreach ( $i in $par ) { 
    $path = $i.Path
    $IdentityReference = $i.IdentityReference
    $AccessControlType = $i.AccessControlType
    $InheritanceFlags = $i.InheritanceFlags
    $PropagationFlags = $i.PropagationFlags
    $FileSystemRights = $i.FileSystemRights
    Write-Output $path $IdentityReference
    $acl = Get-Acl $path
    $permission = $IdentityReference, $FileSystemRights, $InheritanceFlags, $PropagationFlags, $AccessControlType
    $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    $acl | Set-Acl $path
}
