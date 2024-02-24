$here = $PSScriptRoot
$requiredModulesPath = (Resolve-Path -Path $here\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $here\AzHelpers.psm1 -Force
$projectSettings = Get-Content $here\..\source\Global\ProjectSettings.yml | ConvertFrom-Yaml -ErrorAction Stop
$datum = New-DatumStructure -DefinitionFile $here\..\source\Datum.yml
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
    Connect-Azure @param -ErrorAction Stop
    
    Write-Host "Stopping all VMs in $($lab.Name) for environment '$environmentName'" -ForegroundColor Magenta
        
    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
    Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

    Write-Host "Stopping all VMs in $($lab.Name)"
    Stop-LabVM -All
}
