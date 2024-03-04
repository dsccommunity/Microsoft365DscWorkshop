$here = $PSScriptRoot
$requiredModulesPath = (Resolve-Path -Path $here\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $here\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $here\..\source\Datum.yml
$labs = Get-Lab -List | Where-Object { $_ -Like "$($datum.Global.ProjectSettings.Name)*" }

foreach ($lab in $labs)
{
    $lab -match "(?:$($datum.Global.ProjectSettings.Name))(?<Environment>\w+)" | Out-Null
    $environmentName = $Matches.Environment

    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-Azure @param -ErrorAction Stop

    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    Write-Host "Working in lab '$($lab.Name)' with environment '$environmentName'"
    
    if (-not ($id = Get-AzUserAssignedIdentity -Name "Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -ErrorAction SilentlyContinue))
    {
        Write-Host "Managed Identity not found, creating it named 'Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)'"
        $id = New-AzUserAssignedIdentity -Name "Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Location $lab.AzureSettings.DefaultLocation.Location
    }
    
    $vm = Get-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Name "Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)"
    if ($vm.Identity.UserAssignedIdentities.Keys -eq $id.Id)
    {
        Write-Host "Managed Identity already assigned to VM 'Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)' in environment '$environmentName'"
    }
    else
    {
        Write-Host "Assigning Managed Identity to VM 'Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)' in environment '$environmentName'"
        Update-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityId $id.Id | Out-Null
    }

    $appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$("Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)")'"
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Global Reader'"
    New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/" | Out-Null

    Write-Host 'Getting required permissions for all Microsoft365DSC workloads...' -NoNewline
    #$permissions = Get-M365DSCCompiledPermissionList2
    Write-Host "found $($permissions.Count) permissions"

    Write-Host "Setting permissions for managed identity 'Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)' in environment '$environmentName'"
    #Set-ServicePrincipalAppPermissions -DisplayName "Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)" -Permissions $permissions
    
    Disconnect-MgGraph | Out-Null

    #------------------------------------ EXO ----------------------------------------------------

    Connect-Azure @param -ErrorAction Stop

    $tokenBody = @{     
        Grant_Type    = "client_credentials" 
        Scope         = "https://outlook.office365.com/.default"
        Client_Id     = $environment.AzApplicationId 
        Client_Secret = $environment.AzApplicationSecret
    }  

    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$($environment.AzTenantId)/oauth2/v2.0/token" -Method POST -Body $tokenBody 
    
    Connect-ExchangeOnline -AccessToken $tokenResponse.access_token -Organization $environment.AzTenantName -ShowBanner:$false

    if ($servicePrincipal = Get-MgServicePrincipal -Filter "displayName eq '$("Lcm$($datum.Global.ProjectSettings.Name)$($lab.Notes.Environment)")'" -ErrorAction SilentlyContinue)
    {
        Write-Host "The EXO service principal for application '$($datum.Global.ProjectSettings.Name)' already exists in environment '$environmentName' in the subscription '$($subscription.Name)'"
    }
    else
    {
        Write-Host "Creating the EXO service principal for application '$($datum.Global.ProjectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        $servicePrincipal = New-ServicePrincipal -AppId $appRegistration.AppId -ObjectId $appRegistration.Id -DisplayName "Service Principal Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)"
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

    Disconnect-ExchangeOnline -Confirm:$false
}
