[CmdletBinding()]
param (
    [Parameter()]
    [string[]]$EnvironmentName
)

$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*")
{
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

if ($EnvironmentName)
{
    Write-Host "Filtering environments to: $($EnvironmentName -join ', ')" -ForegroundColor Magenta
}
Write-Host "Setting up environments: $($environments -join ', ')" -ForegroundColor Magenta

Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force
$projectSettings = Get-Content $PSScriptRoot\..\source\Global\ProjectSettings.yml | ConvertFrom-Yaml -ErrorAction Stop
$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$labs = Get-Lab -List | Where-Object { $_ -Like "$($projectSettings.Name)*" }

foreach ($lab in $labs)
{
    $lab -match "(?:$($projectSettings.Name))(?<Environment>\w+)" | Out-Null
    $envName = $Matches.Environment
    if ($EnvironmentName -and $envName -notin $EnvironmentName)
    {
        Write-Host "Skipping environment '$envName'" -ForegroundColor Yellow
        continue
    }

    $environment = $datum.Global.Azure.Environments.$envName
    $setupIdentity = $environment.Identities | Where-Object Name -EQ M365DscSetupApplication
    Write-Host "Connecting to environment '$envName'" -ForegroundColor Magenta

    $param = @{
        TenantId               = $environment.AzTenantId
        TenantName             = $environment.AzTenantName
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $setupIdentity.ApplicationId
        ServicePrincipalSecret = $setupIdentity.ApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }

    Connect-M365Dsc @param -ErrorAction Stop

    Write-Host "Stopping all VMs in $($lab.Name) for environment '$envName'" -ForegroundColor Magenta

    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    Write-Host "Stopping all VMs in $($lab.Name)"
    Stop-LabVM -All
}
