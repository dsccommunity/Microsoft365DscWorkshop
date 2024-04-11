$here = $PSScriptRoot
$requiredModulesPath = (Resolve-Path -Path $here\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $here\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $here\..\source\Datum.yml

if ($datum.Global.AzureDevOps.OrganizationName -eq '<OrganizationName>')
{
    $datum.Global.AzureDevOps.OrganizationName = Read-Host -Prompt 'Enter the name of your Azure DevOps organization'
    $datum.Global.AzureDevOps | ConvertTo-Yaml | Out-File $here\..\source\Global\AzureDevOps.yml
}

if ($datum.Global.AzureDevOps.PersonalAccessToken -eq '<PersonalAccessToken>')
{
    $pat = Read-Host -Prompt 'Enter your Azure DevOps Personal Access Token'
    $pass = $datum.__Definition.DatumHandlers.'Datum.ProtectedData::ProtectedDatum'.CommandOptions.PlainTextPassword | ConvertTo-SecureString -AsPlainText -Force
    $datum.Global.AzureDevOps.PersonalAccessToken = $pat | Protect-Datum -Password $pass -MaxLineLength 9999

    $datum.Global.AzureDevOps | ConvertTo-Yaml | Out-File $here\..\source\Global\AzureDevOps.yml
}

if ((git status -s) -like '*source/Global/AzureDevOps.yml')
{
    git add $here\..\source\Global\AzureDevOps.yml
    git commit -m 'Updated Azure DevOps Organization Data' | Out-Null
    git push | Out-Null
}

Set-VSTeamAccount -Account "https://dev.azure.com/$($datum.Global.AzureDevOps.OrganizationName)/" -PersonalAccessToken $datum.Global.AzureDevOps.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization '$($datum.Global.AzureDevOps.OrganizationName)' with PAT."

try
{
    Get-VSTeamPool
}
catch
{
    Write-Error "No data returned from Azure DevOps organization '$($datum.Global.AzureDevOps.OrganizationName)'. The authentication might have failed, please check the Organization Name and the PAT."
    return
}

try
{
    Get-VSTeamProject -Name $datum.Global.AzureDevOps.ProjectName | Out-Null
    Write-Host "Project '$($datum.Global.AzureDevOps.ProjectName)' already exists."
}
catch
{
    $project = Add-VSTeamProject -ProjectName $datum.Global.AzureDevOps.ProjectName -Description 'Microsoft365DSCWorkshop Demo Project' -Visibility public -ProcessTemplate Agile
    Write-Host "Project '$($datum.Global.AzureDevOps.ProjectName)' created."
}

$uri = "https://dev.azure.com/$($datum.Global.AzureDevOps.OrganizationName)/$($datum.Global.AzureDevOps.ProjectName)/_apis/distributedtask/queues/?api-version=5.1"
$queues = Invoke-VSTeamRequest -Url $uri

if (-not ($queues.value.name -eq $datum.Global.AzureDevOps.AgentPoolName))
{
    $requestBodyAgentPool = @{
        name          = $datum.Global.AzureDevOps.AgentPoolName
        autoProvision = $true
        autoUpdate    = $true
        autoSize      = $true
        isHosted      = $false
        poolType      = 'automation'
    } | ConvertTo-Json

    Invoke-VSTeamRequest -Url $uri -Method POST -ContentType 'application/json' -Body $requestBodyAgentPool | Out-Null
    Write-Host "Agent pool '$($datum.Global.AzureDevOps.AgentPoolName)' created."
}
else
{
    Write-Host "Agent pool '$($datum.Global.AzureDevOps.AgentPoolName)' already exists."
}

Write-Host ''
Write-Host "Disabling features in project '$($datum.Global.AzureDevOps.ProjectName)'."
$project = Get-VSTeamProject -Name $datum.Global.AzureDevOps.ProjectName

$featuresToDisable = 'ms.feed.feed', #Artifacts
'ms.vss-work.agile', #Boards
'ms.vss-code.version-control', #Repos
'ms.vss-test-web.test' #Test Plans

foreach ($featureToDisable in $featuresToDisable)
{
    $id = "host/project/$($project.Id)/$featureToDisable"
    $buildFeature = Invoke-VSTeamRequest -Area FeatureManagement -Resource FeatureStates -Id $id
    $buildFeature.state = 'disabled'
    $buildFeature = $buildFeature | ConvertTo-Json

    Write-Host "Disabling feature '$featureToDisable' in project '$($datum.Global.AzureDevOps.ProjectName)'."
    Invoke-VSTeamRequest -Method Patch -ContentType 'application/json' -Body $buildFeature -Area FeatureManagement -Resource FeatureStates -Id $id -Version '7.1-preview.1' | Out-Null
}

Write-Host ''
Write-Host "Creating environments in project '$($datum.Global.AzureDevOps.ProjectName)'."

$environments = $datum.Global.Azure.Environments.Keys
$existingEnvironments = Invoke-VSTeamRequest -Method Get -Area distributedtask -Resource environments -Version '7.1-preview.1' -ProjectName $datum.Global.AzureDevOps.ProjectName

foreach ($environmentName in $environments)
{
    if (-not ($existingEnvironments.value | Where-Object { $_.name -eq $environmentName }))
    {
        Write-Host "Creating environment '$environmentName' in project '$($datum.Global.AzureDevOps.ProjectName)'."
        $requestBodyEnvironment = @{
            name = $environmentName
        } | ConvertTo-Json
    
        Invoke-VSTeamRequest -Method Post -ContentType 'application/json' -Body $requestBodyEnvironment -ProjectName $datum.Global.AzureDevOps.ProjectName -Area distributedtask -Resource environments -Version '7.1-preview.1' | Out-Null
    }
    else
    {
        Write-Host "Environment '$environmentName' already exists in project '$($datum.Global.AzureDevOps.ProjectName)'."
    }
}
