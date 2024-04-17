$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$labs = Get-Lab -List | Where-Object { $_ -Like "$($datum.Global.ProjectSettings.Name)*" }

foreach ($lab in $labs) {
    $lab -match "(?:$($datum.Global.ProjectSettings.Name))(?<Environment>\w+)" | Out-Null
    $environmentName = $Matches.Environment
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Write-Host "Connecting to Azure with service principal '$($environment.AzApplicationId)' for environment '$environmentName'" -ForegroundColor Magenta
    Connect-Azure @param -ErrorAction Stop

    Write-Host "Removing lab '$lab' for environment '$environmentName'" -ForegroundColor Magenta

    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    Remove-Lab -Confirm:$false

    Write-Host "Successfully removed lab '$($lab.Name)'."
}

Set-VSTeamAccount -Account "https://dev.azure.com/$($datum.Global.AzureDevOps.OrganizationName)/" -PersonalAccessToken $datum.Global.AzureDevOps.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization '$($datum.Global.AzureDevOps.OrganizationName)' with PAT."

try {
    Get-VSTeamProject -Name $datum.Global.AzureDevOps.ProjectName | Out-Null
    Remove-VSTeamProject -Name $datum.Global.AzureDevOps.ProjectName -Force -ErrorAction Stop
    Write-Host "Project '$($datum.Global.AzureDevOps.ProjectName)' has been removed."
}
catch {
    Write-Host "Project '$($datum.Global.AzureDevOps.ProjectName)' does not exists."
}

if ($pool = Get-VSTeamPool | Where-Object Name -EQ $datum.Global.AzureDevOps.AgentPoolName) {
    Remove-VSTeamPool -Id $pool.Id
    Write-Host "Agent pool '$($datum.Global.AzureDevOps.AgentPoolName)' has been removed."
}
else {
    Write-Host "Agent pool '$($datum.Global.AzureDevOps.AgentPoolName)' does not exists."
}

Write-Host 'Finished cleanup.'