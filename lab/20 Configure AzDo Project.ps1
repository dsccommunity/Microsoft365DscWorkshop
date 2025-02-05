$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*")
{
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml

# ----------------------------------------------------------
#            Setting project parameters
# ----------------------------------------------------------
if ($datum.Global.ProjectSettings.OrganizationName -eq '<OrganizationName>' -or $null -eq $datum.Global.ProjectSettings.OrganizationName)
{
    $datum.Global.ProjectSettings.OrganizationName = Read-Host -Prompt 'Enter the name of your Azure DevOps organization'
    $datum.Global.ProjectSettings | ConvertTo-Yaml | Out-File $PSScriptRoot\..\source\Global\ProjectSettings.yml
}

if ($datum.Global.ProjectSettings.ProjectName -eq '<ProjectName>' -or $null -eq $datum.Global.ProjectSettings.ProjectName)
{
    $guessedProjectName = $PSScriptRoot.Split('\')[-2]
    $choice = Read-Host -Prompt "Enter the name of your Azure DevOps project or press <Enter> to use the default ($guessedProjectName)"
    if ($choice -eq '')
    {
        $datum.Global.ProjectSettings.ProjectName = $guessedProjectName
    }
    else
    {
        $datum.Global.ProjectSettings.ProjectName = $choice
    }
    $datum.Global.ProjectSettings | ConvertTo-Yaml | Out-File $PSScriptRoot\..\source\Global\ProjectSettings.yml
}

if ($datum.Global.ProjectSettings.PersonalAccessToken -eq '<PersonalAccessToken>' -or $null -eq $datum.Global.ProjectSettings.PersonalAccessToken)
{
    $pat = Read-Host -Prompt 'Enter your Azure DevOps Personal Access Token'
    $pass = $datum.__Definition.DatumHandlers.'Datum.ProtectedData::ProtectedDatum'.CommandOptions.PlainTextPassword | ConvertTo-SecureString -AsPlainText -Force
    $datum.Global.ProjectSettings.PersonalAccessToken = $pat | Protect-Datum -Password $pass -MaxLineLength 9999

    $datum.Global.ProjectSettings | ConvertTo-Yaml | Out-File $PSScriptRoot\..\source\Global\ProjectSettings.yml
}

if ((git status -s) -like '*source/Global/ProjectSettings.yml')
{
    git add $PSScriptRoot\..\source\Global\ProjectSettings.yml
    git commit -m 'Updated Azure DevOps Organization Data' | Out-Null
    git push | Out-Null
}

Set-VSTeamAccount -Account "https://dev.azure.com/$($datum.Global.ProjectSettings.OrganizationName)/" -PersonalAccessToken $datum.Global.ProjectSettings.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization '$($datum.Global.ProjectSettings.OrganizationName)' with PAT."

# ----------------------------------------------------------
#            Creating agent pool and project
# ----------------------------------------------------------
try
{
    Get-VSTeamPool | Out-Null
}
catch
{
    Write-Error "No data returned from Azure DevOps organization '$($datum.Global.ProjectSettings.OrganizationName)'. The authentication might have failed, please check the Organization Name and the PAT."
    return
}

try
{
    Get-VSTeamProject -Name $datum.Global.ProjectSettings.ProjectName -WarningAction SilentlyContinue | Out-Null
    Write-Host "Project '$($datum.Global.ProjectSettings.ProjectName)' already exists."
}
catch
{
    $project = Add-VSTeamProject -ProjectName $datum.Global.ProjectSettings.ProjectName -Description 'Microsoft365DSCWorkshop Demo Project' -Visibility public -ProcessTemplate Agile
    if ($null -eq $project)
    {
        Write-Error "Failed to create project '$($datum.Global.ProjectSettings.ProjectName)'. Please check the warnings above."
        return
    }
    else
    {
        Write-Host "Project '$($datum.Global.ProjectSettings.ProjectName)' created."
    }
}

$uri = "https://dev.azure.com/$($datum.Global.ProjectSettings.OrganizationName)/$($datum.Global.ProjectSettings.ProjectName)/_apis/distributedtask/queues/?api-version=5.1"
$queues = Invoke-VSTeamRequest -Url $uri

if (-not ($queues.value.name -eq $datum.Global.ProjectSettings.AgentPoolName))
{
    $requestBodyAgentPool = @{
        name          = $datum.Global.ProjectSettings.AgentPoolName
        autoProvision = $true
        autoUpdate    = $true
        autoSize      = $true
        isHosted      = $false
        poolType      = 'automation'
    } | ConvertTo-Json

    Invoke-VSTeamRequest -Url $uri -Method POST -ContentType 'application/json' -Body $requestBodyAgentPool | Out-Null
    Write-Host "Agent pool '$($datum.Global.ProjectSettings.AgentPoolName)' created."
}
else
{
    Write-Host "Agent pool '$($datum.Global.ProjectSettings.AgentPoolName)' already exists."
}

Write-Host ''
Write-Host "Disabling features in project '$($datum.Global.ProjectSettings.ProjectName)'."
$project = Get-VSTeamProject -Name $datum.Global.ProjectSettings.ProjectName

$featuresToDisable = 'ms.feed.feed', #Artifacts
'ms.vss-work.agile', #Boards
'ms.vss-test-web.test' #Test Plans
#'ms.vss-code.version-control' #Repos

foreach ($featureToDisable in $featuresToDisable)
{
    $id = "host/project/$($project.Id)/$featureToDisable"
    $buildFeature = Invoke-VSTeamRequest -Area FeatureManagement -Resource FeatureStates -Id $id
    $buildFeature.state = 'disabled'
    $buildFeature = $buildFeature | ConvertTo-Json

    Write-Host "Disabling feature '$featureToDisable' in project '$($datum.Global.ProjectSettings.ProjectName)'."
    Invoke-VSTeamRequest -Method Patch -ContentType 'application/json' -Body $buildFeature -Area FeatureManagement -Resource FeatureStates -Id $id -Version '7.1-preview.1' | Out-Null
}

# ----------------------------------------------------------
#            Creating environments in project
# ----------------------------------------------------------
Write-Host ''
Write-Host "Creating environments in project '$($datum.Global.ProjectSettings.ProjectName)'."

$environments = $datum.Global.Azure.Environments.Keys
$existingEnvironments = Invoke-VSTeamRequest -Method Get -Area distributedtask -Resource environments -Version '7.1-preview.1' -ProjectName $datum.Global.ProjectSettings.ProjectName

foreach ($environment in $environments)
{
    if (-not ($existingEnvironments.value | Where-Object { $_.name -eq $environment }))
    {
        Write-Host "Creating environment '$environment' in project '$($datum.Global.ProjectSettings.ProjectName)'."
        $requestBodyEnvironment = @{
            name = $environment
        } | ConvertTo-Json

        Invoke-VSTeamRequest -Method Post -ContentType application/json -Body $requestBodyEnvironment -ProjectName $datum.Global.ProjectSettings.ProjectName -Area distributedtask -Resource environments -Version 7.1 | Out-Null
    }
    else
    {
        Write-Host "Environment '$environment' already exists in project '$($datum.Global.ProjectSettings.ProjectName)'."
    }
}

# ----------------------------------------------------------
#        Setting environments in pipeline parameters
# ----------------------------------------------------------
Write-Host 'Changing build pipelines to use only the configured environments' -ForegroundColor Yellow

$environments = $datum.Global.Azure.Environments.Keys
$pipelinesToAdapt = 'build.yml', 'export.yml', 'pull.yml', 'push.yml', 'reapply.yml', 'test.yml'
$pipelinesToAdapt = Get-ChildItem -Path ..\pipelines | Where-Object Name -In $pipelinesToAdapt

Write-Host "Known environments: $($environments -join ', ')"
Write-Host 'Pipelines to adapt:'
$pipelinesToAdapt | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host ''

foreach ($pipeline in $pipelinesToAdapt)
{
    Write-Host "Adapting pipeline $($pipeline.FullName)"
    $pipelineYaml = Get-Content $pipeline.FullName -Raw | ConvertFrom-Yaml -Ordered
    $buildEnvironments = $pipelineYaml.parameters | Where-Object Name -EQ buildEnvironments

    $environmentsToRemove = $buildEnvironments.default | Where-Object Name -NotIn $environments
    if ($environmentsToRemove.Count -eq 0)
    {
        Write-Host "  No environments to remove for pipeline '$($pipeline.Name)'"
        continue
    }
    else
    {
        Write-Host "  Removing $($environmentsToRemove.Count) environments from pipeline '$($pipeline.Name)'"
        foreach ($environment in $environmentsToRemove)
        {
            Write-Host "    Removing environment $($environment.Name)"
            [void]$buildEnvironments.default.Remove($environment)
        }
    }

    $pipelineYaml | ConvertTo-Yaml | Out-File -FilePath $pipeline.FullName
}

$changedFiles = git diff --name-only | Where-Object { $_ -like 'pipelines/*.yml' }
if ($changedFiles.Count -gt 0)
{
    Write-Host 'Committing changes to pipelines.'
    foreach ($changedFile in $changedFiles)
    {
        $path = Join-Path -Path .. -ChildPath $changedFile
        git add $path
    }
    git commit -m 'Updated pipelines to use only the configured environments' | Out-Null
    git push | Out-Null
}
else
{
    Write-Host 'No changes to commit, no pipeline was changed.'
}

# ----------------------------------------------------------
#                  Creating pipelines
# ----------------------------------------------------------

Write-Host 'Creating pipelines in project.'
$pipelineNames = 'apply', 'build', 'push', 'test'
foreach ($pipelineName in $pipelineNames)
{
    if (Invoke-VSTeamRequest -Area pipelines -Version 7.1 -Method Get -ProjectName $datum.Global.ProjectSettings.ProjectName | Select-Object -ExpandProperty value | Where-Object { $_.name -eq "M365DSC $pipelineName" })
    {
        Write-Host "Pipeline '$pipelineName' already exists in project '$($datum.Global.ProjectSettings.ProjectName)'."
        continue
    }

    $repo = Get-VSTeamGitRepository -Name $datum.Global.ProjectSettings.ProjectName -ProjectName $datum.Global.ProjectSettings.ProjectName
    $pipelineParams = @{
        configuration = @{
            path       = "pipelines/$pipelineName.yml"
            repository = @{
                id   = $repo.Id
                type = 'azureReposGit'
            }
            type       = 'yaml'
        }
        name          = "M365DSC $pipelineName"
    }

    Write-Host "Creating pipeline '$pipelineName' in project '$($datum.Global.ProjectSettings.ProjectName)'."
    $pipelineParams = $pipelineParams | ConvertTo-Json -Compress
    Invoke-VSTeamRequest -Area pipelines -Version 7.1 -Method Post -Body $pipelineParams -JSON -ProjectName $datum.Global.ProjectSettings.ProjectName | Out-Null
}

Write-Host 'All done.'
