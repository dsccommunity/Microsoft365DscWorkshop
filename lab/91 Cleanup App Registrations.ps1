$here = $PSScriptRoot
$requiredModulesPath = (Resolve-Path -Path $here\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

$datum = New-DatumStructure -DefinitionFile $here\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $datum.Global.Azure.Environments.$environmentName
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
    
    if ($appPrincipal = Get-MgServicePrincipal -Filter "displayName eq '$($datum.Global.ProjectSettings.Name)'" -ErrorAction SilentlyContinue) {
        
        Write-Host "Removing the service principal '$($datum.Global.ProjectSettings.Name)' from the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-AzRoleAssignment -ObjectId $appPrincipal.Id -RoleDefinitionName Owner -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "Removing the service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Remove-MgServicePrincipal -ServicePrincipalId $appPrincipal.Id
    }

    if ($appRegistration = Get-MgApplication -Filter "displayName eq '$($datum.Global.ProjectSettings.Name)'" -ErrorAction SilentlyContinue) {        
        Write-Host "Removing the application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        Remove-MgApplication -ApplicationId $appRegistration.Id
    }

    Write-Host "Finished working in environment '$environmentName' in the subscription '$($subscription.Name)'"

}

Write-Host 'Finished working in all environments'
