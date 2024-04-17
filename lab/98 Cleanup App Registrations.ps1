$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    try {
        $subscription = Connect-AzAccount -Tenant $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop
        Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

        Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop
        $graphContext = Get-MgContext
        Write-Host "Connected to Graph API '$($graphContext.TenantId)' with account '$($graphContext.ClientId)'"
    }
    catch {
        Write-Host "Failed to connect to environment '$environmentName' with error '$($_.Exception.Message)', skipping cleanup." -ForegroundColor Red
        continue
    }
    
    try {
        Write-Host "Connecting to Exchange Online in environment '$environmentName'"
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

        $exchangeConnetion = Get-ConnectionInformation
        if ($exchangeConnetion.TenantId -ne $environment.AzTenantId) {
            Disconnect-ExchangeOnline -Confirm:$false
            Write-Error "Exchange Online is connected to a different tenant '$($exchangeConnetion.TenantId)', skipping cleanup." -ErrorAction Stop
        }
    }
    catch {
        Write-Host "Failed to connect to Exchange Online in environment '$environmentName' with error '$($_.Exception.Message)'" -ForegroundColor Red
        continue
    }

    $servicePrincipal = Get-ServicePrincipal -Identity $datum.Global.ProjectSettings.Name -ErrorAction SilentlyContinue
    if ($servicePrincipal) {
        Write-Host "Removing the EXO service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        Remove-ServicePrincipal -Identity $servicePrincipal.AppId -Confirm:$false
    }
    else {
        Write-Host "Did not find EXO service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
    }
    Disconnect-ExchangeOnline -Confirm:$false

    if ($appPrincipal = Get-MgServicePrincipal -Filter "displayName eq '$($datum.Global.ProjectSettings.Name)'" -ErrorAction SilentlyContinue) {
        
        Write-Host "Removing the service principal '$($datum.Global.ProjectSettings.Name)' from the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        Remove-AzRoleAssignment -ObjectId $appPrincipal.Id -RoleDefinitionName Owner -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "Removing the service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        Remove-MgServicePrincipal -ServicePrincipalId $appPrincipal.Id
    }
    else {
        Write-Host "Did not find service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
    }

    if ($appRegistration = Get-MgApplication -Filter "displayName eq '$($datum.Global.ProjectSettings.Name)'" -ErrorAction SilentlyContinue) {        
        Write-Host "Removing the application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        Remove-MgApplication -ApplicationId $appRegistration.Id
    }
    else {
        Write-Host "Did not find application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
    }

    Write-Host "Finished working in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"

}

Write-Host 'Finished working in all environments'
