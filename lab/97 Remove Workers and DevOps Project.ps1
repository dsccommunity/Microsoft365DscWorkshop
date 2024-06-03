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
$labs = Get-Lab -List | Where-Object { $_ -Like "$($datum.Global.ProjectSettings.Name)*" }

foreach ($lab in $labs)
{
    $lab -match "(?:$($datum.Global.ProjectSettings.Name))(?<Environment>\w+)" | Out-Null
    $envName = $Matches.Environment
    if ($EnvironmentName -and $envName -notin $EnvironmentName)
    {
        Write-Host "Skipping lab '$lab' for environment '$envName'." -ForegroundColor Yellow
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
    Write-Host "Successfully connected to Azure environment '$envName'."

    Write-Host "Removing lab '$lab' for environment '$envName'" -ForegroundColor Magenta

    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    Remove-Lab -Confirm:$false

    Write-Host "Successfully removed lab '$($lab.Name)'."
}

Set-VSTeamAccount -Account "https://dev.azure.com/$($datum.Global.AzureDevOps.OrganizationName)/" -PersonalAccessToken $datum.Global.AzureDevOps.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization '$($datum.Global.AzureDevOps.OrganizationName)' with PAT."

try
{
    Get-VSTeamProject -Name $datum.Global.AzureDevOps.ProjectName | Out-Null
    Remove-VSTeamProject -Name $datum.Global.AzureDevOps.ProjectName -Force -ErrorAction Stop
    Write-Host "Project '$($datum.Global.AzureDevOps.ProjectName)' has been removed."

    if ($pool = Get-VSTeamPool | Where-Object Name -EQ $datum.Global.AzureDevOps.AgentPoolName)
    {
        Remove-VSTeamPool -Id $pool.Id
        Write-Host "Agent pool '$($datum.Global.AzureDevOps.AgentPoolName)' has been removed."
    }
    else
    {
        Write-Host "Agent pool '$($datum.Global.AzureDevOps.AgentPoolName)' does not exists."
    }
}
catch
{
    Write-Host "Project '$($datum.Global.AzureDevOps.ProjectName)' does not exists."
}

Write-Host 'Finished cleanup.'
