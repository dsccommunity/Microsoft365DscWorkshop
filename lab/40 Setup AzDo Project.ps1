$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$azDoData = Get-Content $here\..\source\Global\AzureDevOps.yml | ConvertFrom-Yaml
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

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
    Invoke-VSTeamRequest -Method Patch -ContentType 'application/json' -Body $buildFeature -Area FeatureManagement -Resource FeatureStates -Id $id -Version '7.1-preview.1' | Out-Null
}

Write-Host ''
Write-Host "Creating environments in project '$($azDoData.ProjectName)'."

$environments = $azureData.Environments.Keys
$existingEnvironments = Invoke-VSTeamRequest -Method Get -Area distributedtask -Resource environments -Version '7.1-preview.1' -ProjectName $azDoData.ProjectName

foreach ($environmentName in $environments) {
    if (-not ($existingEnvironments.value | Where-Object { $_.name -eq $environmentName })) {
        Write-Host "Creating environment '$environmentName' in project '$($azDoData.ProjectName)'."
        $requestBodyEnvironment = @{
            name = $environmentName
        } | ConvertTo-Json
    
        Invoke-VSTeamRequest -Method Post -ContentType 'application/json' -Body $requestBodyEnvironment -ProjectName Microsoft365DscWorkshop -Area distributedtask -Resource environments -Version '7.1-preview.1' | Out-Null
    } else {
        Write-Host "Environment '$environmentName' already exists in project '$($azDoData.ProjectName)'."
    }
}
