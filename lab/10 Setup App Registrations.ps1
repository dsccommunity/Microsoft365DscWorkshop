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

    $subscription = Set-AzContext -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction SilentlyContinue
    if (-not $subscription) {
        $null = Connect-AzAccount -Tenant $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop
        $subscription = Get-AzContext
    }

    Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Azure subscription '$($subscription.Name)' and Microsoft Graph with account '$($subscription.Account.Id)'"
    
    if (-not ($appRegistration = Get-MgApplication -Filter "displayName eq '$($datum.Global.ProjectSettings.Name)'" -ErrorAction SilentlyContinue)) {
        Write-Host "Did not find application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'."
        Write-Host "Creating application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        $appRegistration = New-MgApplication -DisplayName $datum.Global.ProjectSettings.Name
        Update-MgApplication -ApplicationId $appRegistration.Id -SignInAudience AzureADMyOrg
        Write-Host "Creating service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        $appPrincipal = New-MgServicePrincipal -AppId $appRegistration.AppId
    
        $passwordCred = @{
            displayName = 'Secret'
            endDateTime = (Get-Date).AddMonths(12)
        }
        Write-Host "Creating password secret for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        $clientSecret = Add-MgApplicationPassword -ApplicationId $appRegistration.Id -PasswordCredential $passwordCred
        
        Write-Host "IMPORTANT: Update the property 'AzApplicationSecret' in the file '\source\Global\Azure.yml' for the correct environment." -ForegroundColor Magenta
        Write-Host "Registered the application '$($datum.Global.ProjectSettings.Name)' for environment '$environmentName' in the subscription '$($subscription.Name)' with password secret" -ForegroundColor Magenta
        Write-Host "  'AzApplicationId: $($appRegistration.AppId)'" -ForegroundColor Magenta
        Write-Host "  'AzApplicationSecret: $($clientSecret.SecretText)'" -ForegroundColor Magenta

        Write-Host "Waiting 10 seconds before assigning the application '$($datum.Global.ProjectSettings.Name)' to the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Start-Sleep -Seconds 10
        Write-Host "Assigning the application '$($datum.Global.ProjectSettings.Name)' to the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        New-AzRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionName Owner | Out-Null
    }
    else {
        Write-Host "Application '$($datum.Global.ProjectSettings.Name)' already exists in environment '$environmentName' in the subscription '$($subscription.Name)'"
    }

    Write-Host "Adding Graph permissions to service principal '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"

    <#
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
    #>

    #------------------------------------ EXO ----------------------------------------------------

    $globalReaders = Get-MgDirectoryRole -Filter "DisplayName eq 'Global Reader'"
    # If the role hasn't been activated, we need to get the role template ID to first activate the role
    if ($globalReaders -eq $null)
    {
        $adminRoleTemplate = Get-MgDirectoryRoleTemplate | Where-Object { $_.DisplayName -eq 'Global Reader' }
        $globalReaders = New-MgDirectoryRole -RoleTemplateId $adminRoleTemplate.Id
    }

    $appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$($appRegistration.DisplayName)'"
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Global Reader'"
    New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/" | Out-Null

    Connect-ExchangeOnline -ShowBanner:$false

    if ($servicePrincipal = Get-ServicePrincipal -Identity $environment.AzApplicationId -ErrorAction SilentlyContinue)
    {
        Write-Host "The EXO service principal for application '$($datum.Global.ProjectSettings.Name)' already exists in environment '$environmentName' in the subscription '$($subscription.Name)'"
    }
    else
    {
        Write-Host "Creating the EXO service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        $servicePrincipal = New-ServicePrincipal -AppId $appRegistration.AppId -ObjectId $appRegistration.Id -DisplayName "Service Principal $($appRegistration.Displayname)"
    }

    if (Get-RoleGroupMember -Identity "Organization Management" | Where-Object Name -eq $servicePrincipal.ObjectId)
    {
        Write-Host "The service principal '$($servicePrincipal.DisplayName)' is already a member of the role 'Organization Management' in environment '$environmentName' in the subscription '$($subscription.Name)'"
    }
    else
    {
        Write-Host "Adding service principal '$($servicePrincipal.DisplayName)' to the role 'Organization Management' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Add-RoleGroupMember "Organization Management" -Member $servicePrincipal.DisplayName
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "Address Lists"
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "E-Mail Address Policies"
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "Mail Recipients"
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "View-Only Configuration"
    }

    Write-Host "Finished working in environment '$environmentName' in the subscription '$($subscription.Name)'"
}

Write-Host 'Finished working in all environments'
