Write-Host 'Checking if the script is running in a git repository...' -NoNewline
$projectUrl = git remote get-url origin *>&1

if ($projectUrl -like '*fatal: not a git repository*' -and $LASTEXITCODE -eq 128)
{
    Write-Host 'Not working in a git repository. Please run the script in a git repository.'
    return
}
else
{
    Write-Host 'ok.'
}

Write-Host 'Checking if the script is running in an Azure DevOps repository...' -NoNewline
if ($projectUrl -notmatch 'https:\/\/(?<OrgName>[\w-]+@)dev.azure.com')
{
    Write-Host 'The script is not running in an Azure DevOps repository. Please run the script in an Azure DevOps repository.'
    return
}
else
{
    Write-Host 'ok.'
}

$projectSettings = Get-Content -Path $PSScriptRoot\..\source\Global\ProjectSettings.yml
if ($projectSettings -contains 'ProjectName: <ProjectName>')
{
    Write-Host "Updating the project name in the 'ProjectSettings.yml' file"
    $projectSettings = $projectSettings -replace '<ProjectName>', (Split-Path -Path (git rev-parse --show-toplevel) -Leaf)
    $projectSettings | Out-File -FilePath $PSScriptRoot\..\source\Global\ProjectSettings.yml
}

$requiredModules = @{
    VSTeam       = '7.15.2'
    AutomatedLab = '5.57.3-preview'
}

foreach ($module in $requiredModules.GetEnumerator())
{
    $param = @{
        Name               = $module.Name
        Scope              = 'AllUsers'
        Force              = $true
        AllowClobber       = $true
        SkipPublisherCheck = $true
    }
    if ($module.Value -like '*preview*')
    {
        $param.AllowPrerelease = $true
    }
    if ($module.Value -ne 'latest')
    {
        $param.RequiredVersion = $module.Value
    }

    $moduleInfo = Get-Module -Name $module.Name -ListAvailable
    if ($module.Value -ne 'latest')
    {
        $moduleInfo = $moduleInfo | Where-Object Version -EQ $module.Value
    }

    if (-not ($moduleInfo))
    {
        Write-Host "Installing module '$($module.Name)' with version '$($module.Value)'"
        Install-Module @param
    }
    else
    {
        Write-Host "Module '$($module.Name)' with version '$($module.Value)' is already installed"
    }
}

Write-Host 'Installing the Azure modules for AutomatedLab...' -NoNewline
Install-LabAzureRequiredModule -Scope AllUsers
Write-Host done.
if (-not (Test-LabAzureModuleAvailability))
{
    Write-Host 'Azure modules for AutomatedLab are still not available. Please restart the script.'
    return
}

Write-Host '------------------------------------------------------------' -ForegroundColor Magenta
Write-Host 'PowerShell may exit during the next step. If it does, please restart the script.' -ForegroundColor Magenta
Write-Host '------------------------------------------------------------' -ForegroundColor Magenta
Write-Host 'Enabling remoting for the lab hosts...' -NoNewline
if (-not (Test-LabHostRemoting))
{
    Enable-LabHostRemoting
}
Write-Host done.
if (-not (Test-LabHostRemoting))
{
    Write-Host 'Remoting for the lab hosts is still not enabled. Please restart the script.'
    return
}

if ($null -eq (git config --global user.email))
{
    $emailAddress = Read-Host -Prompt 'The git user email is not set. Please enter your email address'
    git config --global user.email $emailAddress

    $yourName = Read-Host -Prompt 'The git user name is not set. Please enter your / a name'
    git config --global user.name $yourName
}
else
{
    Write-Host 'Git user email and name are already set.'
}

Write-Host 'Disabling web account manager login for Azure.'
Set-AzConfig -EnableLoginByWam $false | Out-Null
Set-AzConfig -DisplaySecretsWarning $false | Out-Null
Set-Item -Path Env:\AZURE_CLIENTS_SHOW_SECRETS_WARNING -Value $false

Write-Host 'The preparation is done. You can now continue with the next steps.'
