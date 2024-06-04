param (
    [Parameter()]
    [string[]]$EnvironmentName,

    [Parameter()]
    [switch]$DoNotDisconnect
)

$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*")
{
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys

if ($EnvironmentName)
{
    Write-Host "Filtering environments to: $($EnvironmentName -join ', ')" -ForegroundColor Magenta
    $environments = $environments | Where-Object { $EnvironmentName -contains $_ }
}
Write-Host "Setting up environments: $($environments -join ', ')" -ForegroundColor Magenta

foreach ($envName in $environments)
{
    $environment = $datum.Global.Azure.Environments."$envName"
    $setupIdentity = $environment.Identities | Where-Object Name -EQ M365DscSetupApplication
    Write-Host "Testing connection to environment '$envName'" -ForegroundColor Magenta

    $param = @{
        TenantId               = $environment.AzTenantId
        TenantName             = $environment.AzTenantName
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $setupIdentity.ApplicationId
        ServicePrincipalSecret = $setupIdentity.ApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }

    Connect-M365Dsc @param -ErrorAction Stop

    Test-M365DscConnection -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop | Out-Null

    if (-not $DoNotDisconnect)
    {
        Disconnect-M365Dsc
    }
}

Write-Host 'Connection test completed' -ForegroundColor Green
