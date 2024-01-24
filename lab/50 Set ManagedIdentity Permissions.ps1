$here = $PSScriptRoot

$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$environments = $azureData.Environments.Keys
$applicationName = 'Microsoft365DscWorkshop'

foreach ($environmentName in $environments) {
    $environment = $azureData.Environments.$environmentName    
    Write-Host "Checking permissions for environment '$environmentName' (TenantId $($environment.AzTenantId), SubscriptionId $($environment.AzSubscriptionId))"

    $managedIdentityName = "Lcm$($environmentName)"

    $subscription = Set-AzContext -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction SilentlyContinue
    if (-not $subscription) {
        $null = Connect-AzAccount -Tenant $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop
        $subscription = Get-AzContext
    }

    Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Azure subscription '$($subscription.Name)' and Microsoft Graph with account '$($subscription.Account.Id)'"

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
