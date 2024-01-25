$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($lab in $labs)
{
    $lab -match '(?:M365DscWorkshopWorker)(?<Environment>\w+)(?:\d{1,4})' | Out-Null
    $environmentName = $Matches.Environment
    $environment = $azureData.Environments.$environmentName

    Write-Host "Starting all VMs in $($lab.Name) for environment '$environmentName'" -ForegroundColor Magenta
        
    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
    Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

    Write-Host "Stopping all VMs in $($lab.Name)"
    Stop-LabVM -All
}
