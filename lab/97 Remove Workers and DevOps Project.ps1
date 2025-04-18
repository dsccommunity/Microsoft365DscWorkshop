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

Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$labs = Get-Lab -List | Where-Object { $_ -Like "$($datum.Global.ProjectSettings.ProjectName)*" }

foreach ($lab in $labs)
{
    $lab -match "(?:$($datum.Global.ProjectSettings.ProjectName))(?<Environment>\w+)" | Out-Null
    $envName = $Matches.Environment
    $environment = $datum.Global.Azure.Environments.$envName

    if ($EnvironmentName -and $envName -notin $EnvironmentName)
    {
        Write-Host "Skipping lab '$lab' for environment '$envName'." -ForegroundColor Yellow
        continue
    }

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

    Test-M365DscConnection -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop

    $identity = Get-M365DscIdentity -Name "M365DscLcm$($datum.Global.ProjectSettings.ProjectName)$($envName)Identity"
    if ($null -ne $identity)
    {
        Remove-M365DscIdentityPermission -Identity $identity -SkipGraphApiPermissions
        Remove-M365DscIdentity -Name $identity.DisplayName
        Write-Host "Successfully removed identity '$($identity.DisplayName)' for environment '$envName'."
    }
    else
    {
        Write-Host "Identity 'M365DscLcm$($datum.Global.ProjectSettings.ProjectName)$($envName)Identity' does not exists."
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
    Write-Host "Successfully connected to Azure environment '$envName'."

    Write-Host "Removing lab '$lab' for environment '$envName'" -ForegroundColor Magenta

    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    Remove-Lab -Confirm:$false

    Write-Host "Successfully removed lab '$($lab.Name)'."
}

Set-VSTeamAccount -Account "https://dev.azure.com/$($datum.Global.ProjectSettings.OrganizationName)/" -PersonalAccessToken $datum.Global.ProjectSettings.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization '$($datum.Global.ProjectSettings.OrganizationName)' with PAT."

try
{
    Get-VSTeamProject -Name $datum.Global.ProjectSettings.ProjectName | Out-Null
    Remove-VSTeamProject -Name $datum.Global.ProjectSettings.ProjectName -Force -ErrorAction Stop
    Write-Host "Project '$($datum.Global.ProjectSettings.ProjectName)' has been removed."

    if ($pool = Get-VSTeamPool | Where-Object Name -EQ $datum.Global.ProjectSettings.AgentPoolName)
    {
        Remove-VSTeamPool -Id $pool.Id
        Write-Host "Agent pool '$($datum.Global.ProjectSettings.AgentPoolName)' has been removed."
    }
    else
    {
        Write-Host "Agent pool '$($datum.Global.ProjectSettings.AgentPoolName)' does not exists."
    }
}
catch
{
    Write-Host "Project '$($datum.Global.ProjectSettings.ProjectName)' does not exists."
}

Write-Host 'Finished cleanup.'
