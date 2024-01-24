$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($lab in $labs)
{
    $lab -match '(?:M365DscWorkshopWorker)(?<Environment>\w+)(?:\d{1,4})' | Out-Null
    $environment = $Matches.Environment
    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    Write-Host "Working in lab $($lab.Name) with environment '$environment'"
    
    $cred = New-Object pscredential($azureData.Environments.$environment.AzApplicationId, ($azureData.Environments.$environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $azureData.Environments.$environment.AzTenantId -ErrorAction Stop
    Write-Host "Connected to subscription $($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))"
    
    if (-not ($id = Get-AzUserAssignedIdentity -Name "Lcm$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -ErrorAction SilentlyContinue))
    {
        Write-Host "Managed Identity not found, creating it named 'Lcm$($lab.Notes.Environment)'"
        $id = New-AzUserAssignedIdentity -Name "Lcm$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Location $lab.AzureSettings.DefaultLocation.Location
    }
    
    Write-Host "Assigning Managed Identity to VM 'Lcm$($lab.Notes.Environment)'"
    $vm = Get-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Name "Lcm$($lab.Notes.Environment)"
    Update-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityId $id.Id | Out-Null

    Connect-MgGraph -ContextScope Process -TenantId (Get-AzContext).Tenant.Id -Scopes Group.ReadWrite.All, Application.ReadWrite.All, Directory.ReadWrite.All, AppRoleAssignment.ReadWrite.All -NoWelcome -ErrorAction Stop | Out-Null

    Write-Host 'Getting required permissions for managed identity'
    $permissions = Get-M365DSCCompiledPermissionList2

    Write-Host "Setting permissions for managed identity 'Lcm$($lab.Notes.Environment)'"
    Set-ServicePrincipalAppPermissions -DisplayName "Lcm$($lab.Notes.Environment)" -Permissions $permissions
    
    Disconnect-MgGraph
}
