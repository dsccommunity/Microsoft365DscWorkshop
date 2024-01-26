$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$projectSettings = Get-Content $here\..\source\Global\ProjectSettings.yml | ConvertFrom-Yaml -ErrorAction Stop
$environments = $azureData.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $azureData.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    try {
        $subscription = $subscription = Connect-AzAccount -Tenant $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop
        Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

        Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop
        $graphContext = Get-MgContext
        Write-Host "Connected to Graph API '$($graphContext.TenantId)' with account '$($graphContext.ClientId)'"
    }
    catch {
        Write-Host "Failed to connect to environment '$environmentName' with error '$($_.Exception.Message)'" -ForegroundColor Red
        continue
    }
    
    if ($appPrincipal = Get-MgServicePrincipal -Filter "displayName eq '$($projectSettings.Name)'" -ErrorAction SilentlyContinue) {
        
        Write-Host "Removing the service principal '$($projectSettings.Name)' from the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-AzRoleAssignment -ObjectId $appPrincipal.Id -RoleDefinitionName Owner -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "Removing the service principal for application '$($projectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-MgServicePrincipal -ServicePrincipalId $appPrincipal.Id
    }

    if ($appRegistration = Get-MgApplication -Filter "displayName eq '$($projectSettings.Name)'" -ErrorAction SilentlyContinue) {        
        Write-Host "Removing the application '$($projectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        Remove-MgApplication -ApplicationId $appRegistration.Id
    }

    Write-Host "Finished working in environment '$environmentName' in the subscription '$($subscription.Name)'"

}

Write-Host 'Finished working in all environments'
