$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1

$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$environments = $azureData.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $azureData.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta

    # Populate with the App Registration details and Tenant ID
    $appid = $environment.AzApplicationId
    $tenantid = $environment.AzTenantId
    $secret = $environment.AzApplicationSecret

    $body = @{
        Grant_Type    = 'client_credentials'
        Scope         = 'https://graph.microsoft.com/.default'
        Client_Id     = $appid
        Client_Secret = $secret
    }

    $connection = Invoke-RestMethod `
        -Uri https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token `
        -Method POST `
        -Body $body

    $token = $connection.access_token | ConvertTo-SecureString -AsPlainText -Force

    Connect-MgGraph -AccessToken $token
    
    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    try {
        $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
        Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

        Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop
        Write-Host "Connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' and Microsoft Graph with account '$($subscription.Account.Id)'"
    }
    catch {
        Write-Host "Failed to connect to environment '$environmentName' with error '$($_.Exception.Message)'" -ForegroundColor Red
        continue
    }

    Write-Host "Checking permissions for environment '$environmentName' (TenantId $($environment.AzTenantId), SubscriptionId $($environment.AzSubscriptionId))"

    $managedIdentityName = "Lcm$($environmentName)"

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
