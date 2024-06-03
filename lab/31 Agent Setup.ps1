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

if (-not (Test-LabAzureModuleAvailability -ErrorAction SilentlyContinue))
{
    Write-Error "PowerShell modules for AutomateLab Azure integration not found or could not be loaded. Please run 'Install-LabAzureRequiredModule' to install them. If this fails, please restart the PowerShell session and try again."
    return
}

$vsCodeDownloadUrl = 'https://go.microsoft.com/fwlink/?Linkid=852157'
$gitDownloadUrl = 'https://github.com/git-for-windows/git/releases/download/v2.39.2.windows.1/Git-2.39.2-64-bit.exe'
$vscodePowerShellExtensionDownloadUrl = 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/PowerShell/2023.1.0/vspackage'
$notepadPlusPlusDownloadUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.4.9/npp.8.4.9.Installer.x64.exe'
$vstsAgentUrl = 'https://vstsagentpackage.azureedge.net/agent/3.232.3/vsts-agent-win-x64-3.232.3.zip'

foreach ($lab in $labs)
{
    $lab -match "(?:$($datum.Global.ProjectSettings.Name))(?<Environment>\w+)" | Out-Null
    $environmentName = $Matches.Environment
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta

    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-Azure @param -ErrorAction Stop

    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    $vms = Get-LabVM
    Write-Host "Imported lab '$($lab.Name)' with $($vms.Count) machines"

    if ((Get-LabVMStatus) -eq 'Stopped')
    {
        Write-Host "$($vms.Count) machine(s) are stopped. Starting them now."
        Start-LabVM -All -Wait
    }

    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
    Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

    $vscodeInstaller = Get-LabInternetFile -Uri $vscodeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
    $gitInstaller = Get-LabInternetFile -Uri $gitDownloadUrl -Path $labSources\SoftwarePackages -PassThru
    Get-LabInternetFile -Uri $vscodePowerShellExtensionDownloadUrl -Path $labSources\SoftwarePackages\VSCodeExtensions\ps.vsix
    $notepadPlusPlusInstaller = Get-LabInternetFile -Uri $notepadPlusPlusDownloadUrl -Path $labSources\SoftwarePackages -PassThru
    $vstsAgenZip = Get-LabInternetFile -Uri $vstsAgentUrl -Path $labSources\SoftwarePackages -PassThru

    Write-Host "Installing software on $($vms.Count) machines"
    Install-LabSoftwarePackage -Path $vscodeInstaller.FullName -CommandLine /SILENT -ComputerName $vms
    Install-LabSoftwarePackage -Path $gitInstaller.FullName -CommandLine /SILENT -ComputerName $vms
    Install-LabSoftwarePackage -Path $notepadPlusPlusInstaller.FullName -CommandLine /S -ComputerName $vms

    Invoke-LabCommand -Activity 'Connecting LabSources' -ScriptBlock {

        C:\AL\AzureLabSources.ps1

    } -ComputerName $vms

    Invoke-LabCommand -Activity 'Setup AzDo Build Agent' -ScriptBlock {

        if (-not (Get-Service -Name vstsagent*))
        {
            Expand-Archive -Path $vstsAgenZip.FullName -DestinationPath C:\Agent -Force
            "C:\Agent\config.cmd --unattended --url https://dev.azure.com/$($datum.Global.AzureDevOps.OrganizationName) --auth pat --token $($datum.Global.AzureDevOps.PersonalAccessToken) --pool $($datum.Global.AzureDevOps.AgentPoolName) --agent $env:COMPUTERNAME --runAsService --windowsLogonAccount 'NT AUTHORITY\SYSTEM' --acceptTeeEula" | Out-File C:\DeployDebug\AzDoAgentSetup.cmd -Force
            C:\Agent\config.cmd --unattended --url https://dev.azure.com/$($datum.Global.AzureDevOps.OrganizationName) --auth pat --token $($datum.Global.AzureDevOps.PersonalAccessToken) --pool $($datum.Global.AzureDevOps.AgentPoolName) --agent $env:COMPUTERNAME --runAsService --windowsLogonAccount 'NT AUTHORITY\SYSTEM' --acceptTeeEula
        }

    } -ComputerName $vms -Variable (Get-Variable -Name vstsAgenZip, datum)

    Invoke-LabCommand -Activity 'Installing NuGet and PowerShellGet' -ScriptBlock {

        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name PowerShellGet -Force

    } -ComputerName $vms

    Invoke-LabCommand -Activity 'Setting environment variable for build environment' -ScriptBlock {

        [System.Environment]::SetEnvironmentVariable('BuildEnvironment', $args[0], 'Machine')

    } -ComputerName $vms -ArgumentList $lab.Notes.Environment

    Write-Host "Restarting $($vms.Count) machines"
    Restart-LabVM -ComputerName $vms -Wait

    Write-Host "Finished installing AzDo Build Agent on $($vms.Count) machines in environment '$environmentName'"

}
