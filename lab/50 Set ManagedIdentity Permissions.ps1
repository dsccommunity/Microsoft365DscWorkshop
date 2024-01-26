$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$environments = $azureData.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $azureData.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-Azure @param -ErrorAction Stop

    Write-Host "Checking permissions for environment '$environmentName' (TenantId $($environment.AzTenantId), SubscriptionId $($environment.AzSubscriptionId))"

    $managedIdentityName = "Lcm$($projectSettings.Name)$($environmentName)"

    $requiredPermissions = Get-M365DSCCompiledPermissionList2
    $permissions = Get-ServicePrincipalAppPermissions -DisplayName $managedIdentityName

    $permissionDifference = (Compare-Object -ReferenceObject $requiredPermissions -DifferenceObject $permissions).InputObject

    if ($permissionDifference) {
        Write-Warning "There are $($permissionDifference.Count) differences in permissions for managed identity '$managedIdentityName'"
        Write-Host "$($permissionDifference | ConvertTo-Json -Depth 10)"
        Write-Host

        Write-Host "Updating permissions for managed identity '$managedIdentityName'"
        Set-ServicePrincipalAppPermissions -DisplayName $managedIdentityName -Permissions $requiredPermissions
    }
    else {
        Write-Host "Permissions for managed identity '$managedIdentityName' are up to date" -ForegroundColor Green
    }

}
