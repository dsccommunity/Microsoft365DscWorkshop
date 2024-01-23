$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($lab in $labs)
{
    $lab -match '(?:M365DscWorkshopWorker)(?<Environment>\w+)(?:\d{1,4})' | Out-Null
    $environment = $Matches.Environment
    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    $cred = New-Object pscredential($azureData.$environment.AzApplicationId, ($azureData.$environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $azureData.$environment.AzTenantId
    $subscription = Get-AzSubscription -TenantId $azureData.$environment.AzTenantId -SubscriptionId $azureData.$environment.AzSubscriptionId    
    Set-AzContext -SubscriptionId $lab.AzureSettings.DefaultSubscription.SubscriptionId

    Write-Host "Stopping all VMs in $($lab.Name)"
    Stop-LabVM -All
}
