<#
    .SYNOPSIS
        Prepares the local machine for the lab scripts of the Microsoft365DscWorkshop.

    .DESCRIPTION
        This is the first script to run when following the guide in 'docs/GettingStarted.md'.
        It performs these steps:

        - Verifies that the session is elevated and that the repository is a clone of an
          Azure DevOps project.
        - Restores the default module paths, see 'Restore-DefaultModulePath'.
        - Writes the project name into 'source/Global/ProjectSettings.yml'.
        - Installs 'VSTeam', 'AutomatedLab' and 'Pester' with the pinned versions for all users.
        - Installs the Azure modules that AutomatedLab requires.
        - Removes module copies that shadow a newer installation, see 'Resolve-ShadowedModule'.
        - Enables remoting for the lab host.
        - Sets the git user data and the Azure PowerShell defaults the other lab scripts rely on.

        The script takes no parameters. Run it from an elevated PowerShell session in the root
        of the cloned repository.

    .EXAMPLE
        & '.\lab\00 Prep.ps1'

        Runs all preparation steps.

    .NOTES
        Elevation is mandatory as the script installs modules with the scope 'AllUsers' and
        changes the remoting configuration of the lab host.

        Enabling lab host remoting can terminate the PowerShell session. If that happens, open
        a new session and run the script again.

    .LINK
        https://github.com/dsccommunity/Microsoft365DscWorkshop
#>

[CmdletBinding()]

param()

function Restore-DefaultModulePath
{
    <#
        .SYNOPSIS
            Puts the default module paths back into 'PSModulePath' of the current session.

        .DESCRIPTION
            The Sampler build task 'Set_PSModulePath' is configured in 'build.yaml' with
            'RemovePersonal' and 'RemoveProgramFiles', so a session that has run 'build.ps1'
            no longer sees the modules installed for the current user or for all users. In
            such a session this script reinstalls 'AutomatedLab' although it is present, and
            the AutomatedLab commands are still not recognized afterwards.

            This function prepends the default paths of the running PowerShell edition to
            'PSModulePath'. Paths a build has added, like 'output/RequiredModules', are kept
            but move behind the default ones. The change only affects the current process.

        .EXAMPLE
            Restore-DefaultModulePath

            Returns '$true' if paths were missing and have been restored.

        .OUTPUTS
            System.Boolean
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $defaultModulePaths = @(
        if ($PSVersionTable.PSEdition -eq 'Core')
        {
            Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'PowerShell\Modules'
            Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\Modules'
        }
        else
        {
            Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules'
        }
        Join-Path -Path $PSHOME -ChildPath 'Modules'
        Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules'
        Join-Path -Path $env:windir -ChildPath 'System32\WindowsPowerShell\v1.0\Modules'
    )

    $currentModulePaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator | Where-Object { $_ }
    $normalizedModulePaths = $currentModulePaths | ForEach-Object { $_.TrimEnd('\') }
    $missingModulePaths = $defaultModulePaths | Where-Object { $_.TrimEnd('\') -notin $normalizedModulePaths }

    if (-not $missingModulePaths)
    {
        return $false
    }

    $env:PSModulePath = (@($defaultModulePaths) + $currentModulePaths | Select-Object -Unique) -join [System.IO.Path]::PathSeparator

    return $true
}

function Resolve-ShadowedModule
{
    <#
        .SYNOPSIS
            Removes module versions that keep the newest installed version from being imported.

        .DESCRIPTION
            PowerShell does not import the highest installed version of a module. It walks
            'PSModulePath' from left to right and imports the highest version found in the first
            path that contains the module. An outdated copy in an earlier path therefore shadows
            a newer copy in a later path. This is a common cause of the Azure PowerShell error
            'An earlier version of Az.Accounts is imported in the current PowerShell session',
            which no amount of restarting the script can fix.

            This function deletes every copy of the module that is older than the newest installed
            copy and that lives in a 'PSModulePath' entry preceding the one holding the newest
            copy. Copies in later paths are kept as they cannot shadow anything and may be the
            only ones a different PowerShell edition can see.

        .PARAMETER Name
            The name of the module to inspect, for example 'Az.Accounts'.

        .EXAMPLE
            Resolve-ShadowedModule -Name Az.Accounts

            Removes an 'Az.Accounts' copy in the CurrentUser scope if a newer version is installed
            in the AllUsers scope.

        .NOTES
            Only the four standard module scopes are cleaned up. A repository-local module folder
            like 'output/RequiredModules', which a Sampler build adds to 'PSModulePath', is never
            touched.

            Deleting a module fails while another PowerShell session holds its assemblies open.
            The caller is expected to catch that terminating error and to ask the user to close
            the other sessions.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]$Name
    )

    $standardModulePaths = @(
        Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'PowerShell\Modules'
        Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules'
        Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\Modules'
        Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules'
    )
    $modulePaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator |
        Where-Object { $_ -and $_.TrimEnd('\') -in $standardModulePaths }

    $installedModules = Get-Module -Name $Name -ListAvailable
    if (-not $installedModules)
    {
        return
    }

    $newestModule = $installedModules | Sort-Object -Property Version | Select-Object -Last 1

    #PowerShell imports from the first path in 'PSModulePath' containing the module, not from the one with the highest version.
    foreach ($modulePath in $modulePaths)
    {
        if ($newestModule.ModuleBase.StartsWith($modulePath, [StringComparison]::OrdinalIgnoreCase))
        {
            break
        }

        $shadowingModules = $installedModules |
            Where-Object { $_.Version -lt $newestModule.Version -and $_.ModuleBase.StartsWith($modulePath, [StringComparison]::OrdinalIgnoreCase) }

        foreach ($shadowingModule in $shadowingModules)
        {
            Write-Host "Removing '$Name' version '$($shadowingModule.Version)' from '$($shadowingModule.ModuleBase)' as it shadows version '$($newestModule.Version)'."
            Remove-Item -Path $shadowingModule.ModuleBase -Recurse -Force -ErrorAction Stop

            $moduleRoot = Split-Path -Path $shadowingModule.ModuleBase -Parent
            if (-not (Get-ChildItem -Path $moduleRoot -ErrorAction SilentlyContinue))
            {
                Remove-Item -Path $moduleRoot -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Host 'Checking if the script is running with administrative privileges...' -NoNewline
$currentIdentity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentIdentity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host
    Write-Host 'This script installs modules for all users and configures the lab host. Please start PowerShell as administrator and run the script again.' -ForegroundColor Red
    return
}
else
{
    Write-Host 'ok.'
}

Write-Host 'Checking the module path of this session...' -NoNewline
if (Restore-DefaultModulePath)
{
    Write-Host 'restored the default module paths that a build had removed.'
}
else
{
    Write-Host 'ok.'
}

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
    AutomatedLab = '5.61.0'
    # AutomatedLabTest fails the discovery of its own tests under Pester 6, so 'Install-Lab' needs Pester 5 next to it.
    Pester       = '5.7.1'
}

foreach ($module in $requiredModules.GetEnumerator())
{
    $requiredVersion, $prereleaseTag = $module.Value -split '-', 2

    $param = @{
        Name               = $module.Name
        Scope              = 'AllUsers'
        Force              = $true
        AllowClobber       = $true
        SkipPublisherCheck = $true
    }
    if ($prereleaseTag)
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
        #'Version' never carries the prerelease tag, hence both parts are compared separately.
        $moduleInfo = $moduleInfo | Where-Object {
            $_.Version -eq $requiredVersion -and [string]$_.PrivateData.PSData.Prerelease -eq [string]$prereleaseTag
        }
    }

    if ($moduleInfo)
    {
        Write-Host "Module '$($module.Name)' with version '$($module.Value)' is already installed"
        continue
    }

    Write-Host "Installing module '$($module.Name)' with version '$($module.Value)'"
    try
    {
        Install-Module @param -ErrorAction Stop
    }
    catch
    {
        Write-Host "Installing the module '$($module.Name)' failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'PowerShellGet also reports missing administrator rights when the module files are locked by another PowerShell session. Please close all other PowerShell sessions and run the script again.' -ForegroundColor Red
        return
    }
}

Write-Host 'Installing the Azure modules for AutomatedLab...' -NoNewline
Install-LabAzureRequiredModule -Scope AllUsers
Write-Host done.

Write-Host 'Looking for modules that shadow a newer installation.'
try
{
    foreach ($moduleName in (@($requiredModules.Keys) + @((Get-LabConfigurationItem -Name RequiredAzModules).Name)))
    {
        Resolve-ShadowedModule -Name $moduleName
    }
}
catch
{
    Write-Host "Removing a shadowing module failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'The module files are most likely in use. Please close all other PowerShell sessions and run the script again.' -ForegroundColor Red
    return
}

if (-not (Test-LabAzureModuleAvailability))
{
    $loadedAzAccounts = Get-Module -Name Az.Accounts | Sort-Object -Property Version | Select-Object -Last 1
    $newestAzAccounts = Get-Module -Name Az.Accounts -ListAvailable | Sort-Object -Property Version | Select-Object -Last 1

    if ($loadedAzAccounts -and $newestAzAccounts -and $loadedAzAccounts.Version -lt $newestAzAccounts.Version)
    {
        Write-Host "This session has already loaded 'Az.Accounts' version '$($loadedAzAccounts.Version)' but version '$($newestAzAccounts.Version)' is required. PowerShell cannot unload it. Please close this session, open a new one and run the script again." -ForegroundColor Red
    }
    else
    {
        Write-Host 'Azure modules for AutomatedLab are still not available. Please restart the script.' -ForegroundColor Red
    }
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
