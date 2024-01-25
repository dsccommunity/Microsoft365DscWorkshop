$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$projectSettings = Get-Content $here\..\source\Global\ProjectSettings.yml | ConvertFrom-Yaml -ErrorAction Stop
$environments = $azureData.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $azureData.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-Azure @param -ErrorAction Stop
    
    if ($appPrincipal = Get-MgServicePrincipal -Filter "displayName eq '$($projectSettings.Name)'" -ErrorAction SilentlyContinue) {
        
        Write-Host "Removing the service principal '$($projectSettings.Name)' from the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-AzRoleAssignment -ObjectId $appPrincipal.Id -RoleDefinitionName Owner | Out-Null
        
        Write-Host "Removing the service principal for application '$($projectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-MgServicePrincipal -ServicePrincipalId $appPrincipal.Id
    }

    if ($appRegistration = Get-MgApplication -Filter "displayName eq '$($projectSettings.Name)'" -ErrorAction SilentlyContinue) {        
        Write-Host "Removing the application '$($projectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-MgApplication -ApplicationId $appRegistration.Id
    }

    Write-Host "Finished working in environment '$environmentName' in the subscription '$($subscription.Name)'"

}

Write-Host 'Finished working in all environments'
