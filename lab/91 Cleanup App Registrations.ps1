$here = $PSScriptRoot

$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$environments = $azureData.Environments.Keys
$applicationName = 'Microsoft365DscWorkshop'

foreach ($environmentName in $environments) {
    $environment = $azureData.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    $subscription = Set-AzContext -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction SilentlyContinue
    if (-not $subscription) {
        $null = Connect-AzAccount -Tenant $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop
        $subscription = Get-AzContext
    }

    Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop

    Write-Host "Connected to Azure subscription '$($subscription.Name)' and Microsoft Graph with account '$($subscription.Account.Id)'"
    
    if ($appPrincipal = Get-MgServicePrincipal -Filter "displayName eq '$applicationName'" -ErrorAction SilentlyContinue) {
        
        Write-Host "Removing the service principal '$applicationName' from the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-AzRoleAssignment -ObjectId $appPrincipal.Id -RoleDefinitionName Owner | Out-Null
        
        Write-Host "Removing the service principal for application '$applicationName' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-MgServicePrincipal -ServicePrincipalId $appPrincipal.Id
    }

    if ($appRegistration = Get-MgApplication -Filter "displayName eq '$applicationName'" -ErrorAction SilentlyContinue) {        
        Write-Host "Removing the application '$applicationName' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-MgApplication -ApplicationId $appRegistration.Id
    }

    Write-Host "Finished working in environment '$environmentName' in the subscription '$($subscription.Name)'"

}

Write-Host 'Finished working in all environments'
