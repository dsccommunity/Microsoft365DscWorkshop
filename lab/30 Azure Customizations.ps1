$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($lab in $labs)
{
    $lab -match '(?:M365DscWorkshopWorker)(?<Environment>\w+)(?:\d{1,4})'
    $environment = $Matches.Environment | Out-Null
    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    $cred = New-Object pscredential($azureData.$environment.AzApplicationId, ($azureData.$environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $azureData.$environment.AzTenantId
    $subscription = Get-AzSubscription -TenantId $azureData.$environment.AzTenantId -SubscriptionId $azureData.$environment.AzSubscriptionId    
    Set-AzContext -SubscriptionId $lab.AzureSettings.DefaultSubscription.SubscriptionId
    
    if (-not ($id = Get-AzUserAssignedIdentity -Name "Lcm$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -ErrorAction SilentlyContinue))
    {
        $id = New-AzUserAssignedIdentity -Name "Lcm$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Location $lab.AzureSettings.DefaultLocation.Location
    }
    
    $vm = Get-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Name "Lcm$($lab.Notes.Environment)"
    Update-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityId $id.Id

    Connect-MgGraph -ContextScope Process -TenantId (Get-AzContext).Tenant.Id -Scopes Group.ReadWrite.All, Application.ReadWrite.All, Directory.ReadWrite.All, AppRoleAssignment.ReadWrite.All

    $permissions = Get-M365DSCCompiledPermissionList2

    Set-ServicePrincipalAppPermissions -DisplayName "Lcm$($lab.Notes.Environment)" -Permissions $permissions
    Set-ServicePrincipalAppPermissions -DisplayName DSC -Permissions $permissions
    
    Disconnect-MgGraph
}
