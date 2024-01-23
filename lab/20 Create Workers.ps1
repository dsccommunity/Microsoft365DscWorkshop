$here = $PSScriptRoot
$environments = 'Dev', 'Test', 'Prod'

$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($environment in $environments)
{
    $notes = @{
        Environment = $environment
    }

    $subscription = Get-AzSubscription -TenantId $azureData.$environment.AzTenantId -SubscriptionId $azureData.$environment.AzSubscriptionId -ErrorAction SilentlyContinue
    if (-not $subscription) {
        #Connect-AzAccount -Tenant $azureData.Dev.AzTenantId -UseDeviceAuthentication
        #$subscription = Get-AzSubscription -TenantId $azureData.$environment.AzTenantId -SubscriptionId $azureData.$environment.AzSubscriptionId -ErrorAction SilentlyContinue
        $cred = New-Object pscredential($azureData.$environment.AzApplicationId, ($azureData.$environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
        Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $azureData.$environment.AzTenantId
        $subscription = Get-AzSubscription -TenantId $azureData.$environment.AzTenantId -SubscriptionId $azureData.$environment.AzSubscriptionId
    }

    New-LabDefinition -Name "M365DscWorkshopWorker$($environment)$($azureData.LabNumber)" -DefaultVirtualizationEngine Azure -Notes $notes

    Add-LabAzureSubscription -SubscriptionId $subscription.SubscriptionId -DefaultLocation 'UK South'

    Set-LabInstallationCredential -Username Install -Password Somepass1

    $PSDefaultParameterValues = @{
        'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
        'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    }

    Add-LabDiskDefinition -Name "Lcm$($environment)Data1" -DiskSizeInGb 1000 -Label Data

    Add-LabMachineDefinition -Name "Lcm$($environment)" -AzureRoleSize Standard_D8lds_v5 -DiskName "Lcm$($environment)Data1"

    Install-Lab

}
