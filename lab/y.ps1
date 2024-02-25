$aadServicePrincipal = Get-AzADServicePrincipal -SearchString LcmMy365Dev
$servicePrincipal = New-ServicePrincipal -AppId $aadServicePrincipal.AppId -ObjectId $aadServicePrincipal.Id -DisplayName "Service Principal $($aadServicePrincipal.Displayname)"
#New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role 'Organization Management'
Add-RoleGroupMember "Organization Management" -Member $servicePrincipal.DisplayName

$aadServicePrincipal = Get-AzADServicePrincipal -SearchString My365
$servicePrincipal = New-ServicePrincipal -AppId $aadServicePrincipal.AppId -ObjectId $aadServicePrincipal.Id -DisplayName "Service Principal $($aadServicePrincipal.Displayname)"
#New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role 'Organization Management'
Add-RoleGroupMember "Organization Management" -Member $servicePrincipal.DisplayName




New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "Address Lists"
New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "E-Mail Address Policies"
New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "Mail Recipients"
New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "View-Only Configuration"
