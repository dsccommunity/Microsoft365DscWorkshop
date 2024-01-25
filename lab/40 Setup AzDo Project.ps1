$here = $PSScriptRoot
$azDoData = Get-Content $here\..\source\Global\AzureDevOps.yml | ConvertFrom-Yaml

Set-VSTeamAccount -Account "https://dev.azure.com/$($azDoData.OrganizationName)/" -PersonalAccessToken $azDoData.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization '$($azDoData.OrganizationName)' with PAT."

try {
    Get-VSTeamProject -Name $azDoData.ProjectName | Out-Null
    Write-Host "Project '$($azDoData.ProjectName)' already exists."
}
catch {
    $project = Add-VSTeamProject -ProjectName $azDoData.ProjectName -Description 'Microsoft365DSCWorkshop Demo Project' -Visibility public -ProcessTemplate Agile
    Write-Host "Project '$($azDoData.ProjectName)' created."
}

$uri = "https://dev.azure.com/$($azDoData.OrganizationName)/$($azDoData.ProjectName)/_apis/distributedtask/queues/?api-version=5.1"
$queues = Invoke-VSTeamRequest -Url $uri

if (-not ($queues.value.name -eq $azDoData.AgentPoolName)) {
    $requestBodyAgentPool = @{
        name          = $azDoData.AgentPoolName
        autoProvision = $true
        autoUpdate    = $true
        autoSize      = $true
        isHosted      = $false
        poolType      = 'automation'
    } | ConvertTo-Json

    Invoke-VSTeamRequest -Url $uri -Method POST -ContentType 'application/json' -Body $requestBodyAgentPool | Out-Null
    Write-Host "Agent pool '$($azDoData.AgentPoolName)' created."
}
else {
    Write-Host "Agent pool '$($azDoData.AgentPoolName)' already exists."
}

Write-Host ''
Write-Host "Disabling features in project '$($azDoData.ProjectName)'."
$project = Get-VSTeamProject -Name $azDoData.ProjectName

$featuresToDisable = 'ms.feed.feed', #Artifacts
'ms.vss-work.agile', #Boards
'ms.vss-code.version-control', #Repos
'ms.vss-test-web.test' #Test Plans

foreach ($featureToDisable in $featuresToDisable) {
    $id = "host/project/$($project.Id)/$featureToDisable"
    $buildFeature = Invoke-VSTeamRequest -Area FeatureManagement -Resource FeatureStates -Id $id
    $buildFeature.state = 'disabled'
    $buildFeature = $buildFeature | ConvertTo-Json

    Write-Host "Disabling feature '$featureToDisable' in project '$($azDoData.ProjectName)'."
    Invoke-VSTeamRequest -Method Patch -ContentType 'application/json' -Body $buildFeature -Area FeatureManagement -Resource FeatureStates -Id $id -Version '4.1-preview.1'
}
