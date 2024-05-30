$appPrincipal = Get-ServicePrincipal -Identity LcmNew365Prod
Get-MgRoleManagementDirectoryRoleAssignment | Where-Object PrincipalId -eq $appPrincipal.Id | ForEach-Object { Get-MgRoleManagementDirectoryRoleDefinition -Filter "Id eq '$($_.RoleDefinitionId)'" }

Get-ManagementRoleAssignment | Where-Object { $_.RoleAssigneeType -eq 'ServicePrincipal' -and $_.EffectiveUserName -eq $appPrincipal.Id }

$appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'ProdLcmRead'"
Get-MgRoleManagementDirectoryRoleAssignment |
Where-Object PrincipalId -eq $appPrincipal.Id |
ForEach-Object {
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "Id eq '$($_.RoleDefinitionId)'"
    [PSCustomObject]@{
        RoleAssignmentId = $_.Id
        RoleDisplayName = $roleDefinition.DisplayName
        RoleId = $roleDefinition.Id
        RoleDescription = $roleDefinition.Description
        IsBuiltIn = $roleDefinition.IsBuiltIn
        IsEnabled = $roleDefinition.IsEnabled
    }
}

Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId 3ywjKSOT_UKt4h0JevPk3hyL47-4hX5Dtmc7inRaKSY-1
$appPrincipal = Get-ServicePrincipal -Identity ProdLcmRead
Get-ManagementRoleAssignment | Where-Object { $_.RoleAssigneeType -eq 'ServicePrincipal' -and $_.EffectiveUserName -eq $appPrincipal.Id }

Add-RoleGroupMember -Identity "View-Only Organization Management" -Member $servicePrincipal.DisplayName
add-RoleGroupMember -Identity "Security Reader" -Member $servicePrincipal.DisplayName
add-RoleGroupMember -Identity "Organization Management" -Member $servicePrincipal.DisplayName
add-RoleGroupMember -Identity "Recipient Management" -Member $servicePrincipal.DisplayName
add-RoleGroupMember -Identity "Security Administrator" -Member $servicePrincipal.DisplayName


Get-RoleGroupMember -Identity 'View-Only Organization Management' | ForEach-Object { Get-ServicePrincipal -Identity $_.Name }
Get-RoleGroupMember -Identity 'Security Reader' | ForEach-Object { Get-ServicePrincipal -Identity $_.Name }
Get-RoleGroupMember -Identity 'Organization Management' | ForEach-Object { Get-ServicePrincipal -Identity $_.Name }
Get-RoleGroupMember -Identity 'Recipient Management' | ForEach-Object { Get-ServicePrincipal -Identity $_.Name }
Get-RoleGroupMember -Identity 'Security Administrator' | ForEach-Object { Get-ServicePrincipal -Identity $_.Name }


Remove-RoleGroupMember -Identity 'Security Administrator' -Member $servicePrincipal.DisplayName -Confirm:$false
Remove-RoleGroupMember -Identity 'Recipient Management' -Member $servicePrincipal.DisplayName -Confirm:$false
Remove-RoleGroupMember -Identity 'Organization Management' -Member $servicePrincipal.DisplayName -Confirm:$false

