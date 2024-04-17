$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force
$projectSettings = Get-Content $PSScriptRoot\..\source\Global\ProjectSettings.yml | ConvertFrom-Yaml -ErrorAction Stop
$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$labs = Get-Lab -List | Where-Object { $_ -Like "$($projectSettings.Name)*" }

foreach ($lab in $labs)
{
    $lab -match "(?:$($projectSettings.Name))(?<Environment>\w+)" | Out-Null
    $environmentName = $Matches.Environment
    $environment = $datum.Global.Azure.Environments.$environmentName

    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Write-Host "Connecting to Azure with service principal '$($environment.AzApplicationId)' for environment '$environmentName'" -ForegroundColor Magenta
    Connect-Azure @param -ErrorAction Stop

    Write-Host "Starting all VMs in $($lab.Name) for environment '$environmentName'" -ForegroundColor Magenta
        
    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
    Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

    Write-Host "Starting all VMs in $($lab.Name)"
    Start-LabVM -All
}
