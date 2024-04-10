$here = $PSScriptRoot
$requiredModulesPath = (Resolve-Path -Path $here\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $here\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $here\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys

if (-not (Test-LabAzureModuleAvailability)) {
    Install-LabAzureRequiredModule -Scope AllUsers
}

foreach ($environmentName in $environments) {
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-Azure @param -ErrorAction Stop
}

foreach ($environmentName in $environments) {
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    $notes = @{
        Environment = $environmentName
    }

    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
    Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

    Write-Host "Creating lab for environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name)'"
    New-LabDefinition -Name "$($datum.Global.ProjectSettings.Name)$($environmentName)" -DefaultVirtualizationEngine Azure -Notes $notes

    Add-LabAzureSubscription -SubscriptionId $subscription.Context.Subscription.Id -DefaultLocation $datum.Global.AzureDevOps.AgentAzureLocation

    Set-LabInstallationCredential -Username Install -Password Somepass1

    $PSDefaultParameterValues = @{
        'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
        'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    }

    Add-LabDiskDefinition -Name "Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)Data1" -DiskSizeInGb 1000 -Label Data

    Add-LabMachineDefinition -Name "Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)" -AzureRoleSize Standard_D8lds_v5 -DiskName "Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)Data1"

    Install-Lab

    Write-Host "Finished creating lab for environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name)'"

}

Write-Host "Finished creating all labs VMs for the project '$($datum.Global.ProjectSettings.Name)'" -ForegroundColor Green
Write-Host "Starting to assign managed identity to VMs and set permissions for Microsoft365DSC workloads" -ForegroundColor Green

foreach ($lab in $labs)
{
    $lab -match "(?:$($datum.Global.ProjectSettings.Name))(?<Environment>\w+)" | Out-Null
    $environmentName = $Matches.Environment

    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $azureParams = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-Azure @azureParams -ErrorAction Stop

    $exoParams = @{
        TenantId               = $environment.AzTenantId
        TenantName             = $environment.AzTenantName
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret
    }
    Connect-EXO @exoParams -ErrorAction Stop

    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    $resourceGroupName = $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName
    Write-Host "Working in lab '$($lab.Name)' with environment '$environmentName'"
    
    if (-not ($id = Get-AzUserAssignedIdentity -Name "Lcm$($datum.Global.ProjectSettings.Name)$environmentName" -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue))
    {
        Write-Host "Managed Identity not found, creating it named 'Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)'"
        $id = New-AzUserAssignedIdentity -Name "Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Location $lab.AzureSettings.DefaultLocation.Location
    }
    
    $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name "Lcm$($datum.Global.ProjectSettings.Name)$environmentName"
    if ($vm.Identity.UserAssignedIdentities.Keys -eq $id.Id)
    {
        Write-Host "Managed Identity already assigned to VM 'Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)' in environment '$environmentName'"
    }
    else
    {
        Write-Host "Assigning Managed Identity to VM 'Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)' in environment '$environmentName'"
        Update-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityId $id.Id | Out-Null
    }

    $appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$("Lcm$($datum.Global.ProjectSettings.Name)$environmentName")'"
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Global Reader'"
    if (-not (Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$($roleDefinition.Id)' and principalId eq '$($appPrincipal.Id)'"))
    {
        New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/" | Out-Null
    }

    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Exchange Administrator'"
    if (-not (Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$($roleDefinition.Id)' and principalId eq '$($appPrincipal.Id)'"))
    {
        New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/" | Out-Null
    }

    Write-Host 'Getting required permissions for all Microsoft365DSC workloads...' -NoNewline
    $permissions = Get-M365DSCCompiledPermissionList2
    Write-Host "found $($permissions.Count) permissions"

    Write-Host "Setting permissions for managed identity 'Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)' in environment '$environmentName'"
    Set-ServicePrincipalAppPermissions -DisplayName "Lcm$($datum.Global.ProjectSettings.Name)$environmentName" -Permissions $permissions

    #------------------------------------ EXO ----------------------------------------------------

    $lcmServicePrincipalName = "Lcm$($datum.Global.ProjectSettings.Name)$environmentName"
    if ($servicePrincipal = Get-ServicePrincipal -Identity $appPrincipal.Id -ErrorAction SilentlyContinue)
    {
        Write-Host "The EXO service principal for application '$lcmServicePrincipalName' already exists in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
    }
    else
    {
        Write-Host "Creating the EXO service principal for application '$lcmServicePrincipalName' in environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))'"
        $servicePrincipal = New-ServicePrincipal -AppId $appPrincipal.AppId -ObjectId $appPrincipal.Id -DisplayName $lcmServicePrincipalName
    }

    if (Get-RoleGroupMember -Identity "Organization Management" | Where-Object Name -eq $servicePrincipal.ObjectId)
    {
        Write-Host "The service principal '$($servicePrincipal.DisplayName)' is already a member of the role 'Organization Management' in environment '$environmentName' in the subscription '$($subscription.Name)'"
    }
    else
    {
        Write-Host "Adding service principal '$($servicePrincipal.DisplayName)' to the role 'Organization Management' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Add-RoleGroupMember "Organization Management" -Member $servicePrincipal.DisplayName

        $role = Get-RoleGroup -Filter 'Name -eq "Security Administrator"'
        Add-RoleGroupMember -Identity $role.ExchangeObjectId -Member $servicePrincipal.DisplayName
        Add-RoleGroupMember -Identity 'Recipient Management' -Member $servicePrincipal.DisplayName

        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "Address Lists"
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "E-Mail Address Policies"
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "Mail Recipients"
        New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "View-Only Configuration"
    }

    Disconnect-ExchangeOnline -Confirm:$false
    Disconnect-MgGraph | Out-Null
}

Write-Host "Finished assigning managed identity to VMs and setting permissions for Microsoft365DSC workloads" -ForegroundColor Green

Write-Host 'All done.'