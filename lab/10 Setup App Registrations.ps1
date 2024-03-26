$here = $PSScriptRoot
$requiredModulesPath = (Resolve-Path -Path $here\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $here\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $here\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    $subscription =  Connect-AzAccount -Tenant $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop
    Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

    Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop
    $graphContext = Get-MgContext
    Write-Host "Connected to Graph API '$($graphContext.TenantId)' with account '$($graphContext.ClientId)'"
    
    if (-not ($appRegistration = Get-MgApplication -Filter "displayName eq '$($datum.Global.ProjectSettings.Name)'" -ErrorAction SilentlyContinue)) {
        Write-Host "Did not find application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'."
        Write-Host "Creating application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        $appRegistration = New-MgApplication -DisplayName $datum.Global.ProjectSettings.Name
        Update-MgApplication -ApplicationId $appRegistration.Id -SignInAudience AzureADMyOrg
        Write-Host "Creating service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        $appPrincipal = New-MgServicePrincipal -AppId $appRegistration.AppId
    
        $passwordCred = @{
            displayName = 'Secret'
            endDateTime = (Get-Date).AddMonths(12)
        }
        Write-Host "Creating password secret for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        $clientSecret = Add-MgApplicationPassword -ApplicationId $appRegistration.Id -PasswordCredential $passwordCred
        
        Write-Host "IMPORTANT: Update the property 'AzApplicationSecret' in the file '\source\Global\Azure.yml' for the correct environment." -ForegroundColor Magenta
        Write-Host "Registered the application '$($datum.Global.ProjectSettings.Name)' for environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with password secret" -ForegroundColor Magenta
        Write-Host "  'AzApplicationId: $($appRegistration.AppId)'" -ForegroundColor Magenta
        Write-Host "  'AzApplicationSecret: $($clientSecret.SecretText)'" -ForegroundColor Magenta

        Write-Host "Waiting 10 seconds before assigning the application '$($datum.Global.ProjectSettings.Name)' to the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        Start-Sleep -Seconds 10
        Write-Host "Assigning the application '$($datum.Global.ProjectSettings.Name)' to the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        New-AzRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionName Owner | Out-Null
    }
    else {
        Write-Host "Application '$($datum.Global.ProjectSettings.Name)' already exists in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
    }

    Write-Host "Adding Graph permissions to service principal '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"

    $requiredPermissions = Get-M365DSCCompiledPermissionList2
    $requiredPermissions += Get-GraphPermission -PermissionName AppRoleAssignment.ReadWrite.All
    $permissions = @(Get-ServicePrincipalAppPermissions -DisplayName $datum.Global.ProjectSettings.Name)

    $permissionDifference = (Compare-Object -ReferenceObject $requiredPermissions -DifferenceObject $permissions).InputObject

    if ($permissionDifference) {
        Write-Host "There are $($permissionDifference.Count) permissions missing for managed identity '$($datum.Global.ProjectSettings.Name)'"
        Write-Host "Updating permissions for managed identity '$($datum.Global.ProjectSettings.Name)'"
        Set-ServicePrincipalAppPermissions -DisplayName $datum.Global.ProjectSettings.Name -Permissions $requiredPermissions
    }
    else {
        Write-Host "Permissions for managed identity '$($datum.Global.ProjectSettings.Name)' are up to date" -ForegroundColor Green
    }

    #------------------------------------ EXO ----------------------------------------------------

    $globalReaders = Get-MgDirectoryRole -Filter "DisplayName eq 'Global Reader'"
    # If the role hasn't been activated, we need to get the role template ID to first activate the role
    if ($null -eq $globalReaders)
    {
        $adminRoleTemplate = Get-MgDirectoryRoleTemplate | Where-Object { $_.DisplayName -eq 'Global Reader' }
        $globalReaders = New-MgDirectoryRole -RoleTemplateId $adminRoleTemplate.Id
    }

    $appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$($appRegistration.DisplayName)'"
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Global Reader'"
    New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/" | Out-Null

    $appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$($appRegistration.DisplayName)'"
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Exchange Administrator'"
    New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/" | Out-Null

    try
    {
        Write-Host "Connecting to Exchange Online in environment '$environmentName'"
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

        $exchangeConnetion = Get-ConnectionInformation
        if ($exchangeConnetion.TenantId -ne $environment.AzTenantId) {
            Disconnect-ExchangeOnline -Confirm:$false
            Write-Error "Exchange Online is connected to a different tenant '$($exchangeConnetion.TenantId)', skipping configuring this environment." -ErrorAction Stop
        }
    }
    catch
    {
        Write-Host "Failed to connect to Exchange Online in environment '$environmentName' with error '$($_.Exception.Message)'" -ForegroundColor Red
        continue
    }

    if ($servicePrincipal = Get-ServicePrincipal -Identity $environment.AzApplicationId -ErrorAction SilentlyContinue)
    {
        Write-Host "The EXO service principal for application '$($datum.Global.ProjectSettings.Name)' already exists in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
    }
    else
    {
        Write-Host "Creating the EXO service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        $servicePrincipal = New-ServicePrincipal -AppId $appRegistration.AppId -ObjectId $appRegistration.Id -DisplayName "Service Principal $($appRegistration.Displayname)"
    }

    if (Get-RoleGroupMember -Identity "Organization Management" | Where-Object Name -eq $servicePrincipal.ObjectId)
    {
        Write-Host "The service principal '$($servicePrincipal.DisplayName)' is already a member of the role 'Organization Management' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
    }
    else
    {
        Write-Host "Adding service principal '$($servicePrincipal.DisplayName)' to the role 'Organization Management' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        $orgConfig = Get-OrganizationConfig
        if ($orgConfig.IsDehydrated)
        {
            Disconnect-ExchangeOnline -Confirm:$false
            Write-Error "The Exchange Organization is not enabled for customization. Please call 'Enable-OrganizationCustomization' to initialize the organization first. The envionment '$environmentName' could not be configured." -ErrorAction Stop
        }

        Add-RoleGroupMember "Organization Management" -Member $servicePrincipal.DisplayName

        $role = Get-RoleGroup -Filter 'Name -eq "Security Administrator"'
        Add-RoleGroupMember -Identity $role.ExchangeObjectId -Member $servicePrincipal.DisplayName
        Add-RoleGroupMember -Identity 'Recipient Management' -Member $servicePrincipal.DisplayName

        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "Address Lists" | Out-Null
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "E-Mail Address Policies" | Out-Null
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "Mail Recipients" | Out-Null
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "View-Only Configuration" | Out-Null
    }
    Disconnect-ExchangeOnline -Confirm:$false

    Write-Host "Finished working in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
}

Write-Host 'Finished working in all environments'
