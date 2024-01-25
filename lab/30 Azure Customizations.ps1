$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($lab in $labs)
{
    $lab -match '(?:M365DscWorkshopWorker)(?<Environment>\w+)(?:\d{1,4})' | Out-Null
    $environmentName = $Matches.Environment

    $environment = $azureData.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    try {
        $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
        Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

        Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop
        $graphContext = Get-MgContext
        Write-Host "Connected to Graph API '$($graphContext.TenantId)' with account '$($graphContext.ClientId)'"
    }
    catch {
        Write-Host "Failed to connect to environment '$environmentName' with error '$($_.Exception.Message)'" -ForegroundColor Red
        continue
    }

    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    Write-Host "Working in lab $($lab.Name) with environment '$environmentName'"
    
    if (-not ($id = Get-AzUserAssignedIdentity -Name "Lcm$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -ErrorAction SilentlyContinue))
    {
        Write-Host "Managed Identity not found, creating it named 'Lcm$($environmentName)'"
        $id = New-AzUserAssignedIdentity -Name "Lcm$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Location $lab.AzureSettings.DefaultLocation.Location
    }
    
    Write-Host "Assigning Managed Identity to VM 'Lcm$($lab.Notes.Environment)' in environment '$environmentName'"
    $vm = Get-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Name "Lcm$($lab.Notes.Environment)"
    Update-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityId $id.Id | Out-Null

    Write-Host 'Getting required permissions for all Microsoft365DSC workloads...' -NoNewline
    $permissions = Get-M365DSCCompiledPermissionList2
    Write-Host "found $($permissions.Count) permissions"

    Write-Host "Setting permissions for managed identity 'Lcm$($environmentName)' in environment '$environmentName'"
    Set-ServicePrincipalAppPermissions -DisplayName "Lcm$($lab.Notes.Environment)" -Permissions $permissions
    
    Disconnect-MgGraph | Out-Null

}
