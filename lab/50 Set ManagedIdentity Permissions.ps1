$here = $PSScriptRoot
Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -ErrorAction Stop

$environments = $datum.Global.Azure.Keys
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($environment in $environments)
{
    Write-Host "Checking permissions for environment '$environment' (TenantId $($datum.Global.Azure.$environment.AzTenantId), SubscriptionId $($datum.Global.Azure.$environment.AzSubscriptionId))"

    $managedIdentityName = "Lcm$($environment)"
    $environment = $datum.Global.Azure.$environment

    Connect-MgGraph -ContextScope Process -TenantId $environment.AzTenantId -Scopes Group.ReadWrite.All, 'Application.ReadWrite.All', 'Directory.ReadWrite.All', AppRoleAssignment.ReadWrite.All | Out-Null
    Connect-AzAccount -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId | Out-Null

    $requiredPermissions = Get-M365DSCCompiledPermissionList2
    $permissions = Get-ServicePrincipalAppPermissions -DisplayName $managedIdentityName

    $permissionDifference = (Compare-Object -ReferenceObject $requiredPermissions -DifferenceObject $permissions).InputObject

    if ($permissionDifference)
    {
        Write-Warning "There are $($permissionDifference.Count) differences in permissions for managed identity '$managedIdentityName'"
        Write-Host "$($permissionDifference | ConvertTo-Json -Depth 10)"
        Write-Host

        Write-Host "Updating permissions for managed identity '$managedIdentityName'"
        Set-ServicePrincipalAppPermissions -DisplayName $managedIdentityName -Permissions $requiredPermissions
    }
    else
    {
        Write-Host "Permissions for managed identity '$managedIdentityName' are up to date" -ForegroundColor Green
    }

}
