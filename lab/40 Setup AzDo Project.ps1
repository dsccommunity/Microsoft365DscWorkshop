$here = $PSScriptRoot
$azDoData = Get-Content $here\..\source\Global\AzureDevOps.yml | ConvertFrom-Yaml

Set-VSTeamAccount -Account "https://dev.azure.com/$($azDoData.OrganizationName)/" -PersonalAccessToken $azDoData.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization $($azDoData.OrganizationName) with PAT."

try {
    Get-VSTeamProject -Name $azDoData.ProjectName | Out-Null
    Write-Host "Project $($azDoData.ProjectName) already exists."
}
catch {
    $project = Add-VSTeamProject -ProjectName $azDoData.ProjectName -Description 'Microsoft365DSCWorkshop Demo Project' -Visibility public -ProcessTemplate Agile
    Write-Host "Project $($azDoData.ProjectName) created."
}

$uri = "https://dev.azure.com/$($azDoData.OrganizationName)/$($azDoData.ProjectName)/_apis/distributedtask/queues/?api-version=5.1"
$queues = Invoke-VSTeamRequest -Url $uri

if (-not ($queues.value.name -eq $azDoData.AgentPoolName)){
    $requestBodyAgentPool = @{
        name          = $azDoData.AgentPoolName
        autoProvision = $true
        autoUpdate    = $true
        autoSize      = $true
        isHosted      = $false
        poolType      = 'automation'
    } | ConvertTo-Json

    Invoke-VSTeamRequest -Url $uri -Method POST -ContentType 'application/json' -Body $requestBodyAgentPool -QueryString api-version=5.1 | Out-Null
    Write-Host "Agent pool '$($azDoData.AgentPoolName)' created."
}
else {
    Write-Host "Agent pool '$($azDoData.AgentPoolName)' already exists."
}
