$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml -ErrorAction Stop
$azDoData = Get-Content $here\..\source\Global\AzureDevOps.yml | ConvertFrom-Yaml -ErrorAction Stop
$projectSettings = Get-Content $here\..\source\Global\ProjectSettings.yml | ConvertFrom-Yaml -ErrorAction Stop
$labs = Get-Lab -List | Where-Object { $_ -Like "$($projectSettings.Name)*" }

foreach ($lab in $labs) {
    $lab -match "(?:$($projectSettings.Name))(?<Environment>\w+)" | Out-Null
    $environmentName = $Matches.Environment
    $environment = $azureData.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-Azure @param -ErrorAction Stop

    Write-Host "Removing lab '$lab' for environment '$environmentName'" -ForegroundColor Magenta

    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    Remove-Lab -Confirm:$false

    Write-Host "Successfully removed lab '$($lab.Name)'."
}

Set-VSTeamAccount -Account "https://dev.azure.com/$($azDoData.OrganizationName)/" -PersonalAccessToken $azDoData.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization '$($azDoData.OrganizationName)' with PAT."

try {
    Get-VSTeamProject -Name $azDoData.ProjectName | Out-Null
    Remove-VSTeamProject -Name $azDoData.ProjectName -Force -ErrorAction Stop
    Write-Host "Project '$($azDoData.ProjectName)' has been removed."
}
catch {
    Write-Host "Project '$($azDoData.ProjectName)' does not exists."
}

if ($pool = Get-VSTeamPool | Where-Object Name -EQ $azDoData.AgentPoolName) {
    Remove-VSTeamPool -Id $pool.Id
    Write-Host "Agent pool '$($azDoData.AgentPoolName)' has been removed."
}
else {
    Write-Host "Agent pool '$($azDoData.AgentPoolName)' does not exists."
}

Write-Host 'Finished cleanup.'