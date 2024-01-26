$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$projectSettings = Get-Content $here\..\source\Global\ProjectSettings.yml | ConvertFrom-Yaml -ErrorAction Stop
$labs = Get-Lab -List | Where-Object { $_ -Like "$($projectSettings.Name)*" }

foreach ($lab in $labs)
{
    $lab -match "(?:$($projectSettings.Name))(?<Environment>\w+)" | Out-Null
    $environmentName = $Matches.Environment

    $environment = $azureData.Environments.$environmentName
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
    
    if (-not ($id = Get-AzUserAssignedIdentity -Name "Lcm$($projectSettings.Name)$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -ErrorAction SilentlyContinue))
    {
        Write-Host "Managed Identity not found, creating it named 'Lcm$($projectSettings.Name)$($environmentName)'"
        $id = New-AzUserAssignedIdentity -Name "Lcm$($projectSettings.Name)$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Location $lab.AzureSettings.DefaultLocation.Location
    }
    
    Write-Host "Assigning Managed Identity to VM 'Lcm$($projectSettings.Name)$($lab.Notes.Environment)' in environment '$environmentName'"
    $vm = Get-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Name "Lcm$($projectSettings.Name)$($lab.Notes.Environment)"
    Update-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityId $id.Id | Out-Null

    Write-Host 'Getting required permissions for all Microsoft365DSC workloads...' -NoNewline
    $permissions = Get-M365DSCCompiledPermissionList2
    Write-Host "found $($permissions.Count) permissions"

    Write-Host "Setting permissions for managed identity 'Lcm$($projectSettings.Name)$($environmentName)' in environment '$environmentName'"
    Set-ServicePrincipalAppPermissions -DisplayName "Lcm$($projectSettings.Name)$($lab.Notes.Environment)" -Permissions $permissions
    
    Disconnect-MgGraph | Out-Null

}
