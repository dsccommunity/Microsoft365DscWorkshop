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

if ($EnvironmentName)
{
    Write-Host "Filtering environments to: $($EnvironmentName -join ', ')" -ForegroundColor Magenta
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
    $envName = $Matches.Environment
    if ($EnvironmentName -and $envName -notin $EnvironmentName)
    {
        Write-Host "Skipping environment '$envName'" -ForegroundColor Yellow
        continue
    }

    $environment = $datum.Global.Azure.Environments.$envName
    $setupIdentity = $environment.Identities | Where-Object Name -EQ M365DscSetupApplication
    Write-Host "Working in environment '$envName'" -ForegroundColor Magenta

    Write-Host "Connecting to environment '$envName'" -ForegroundColor Magenta
    $param = @{
        TenantId               = $environment.AzTenantId
        TenantName             = $environment.AzTenantName
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $setupIdentity.ApplicationId
        ServicePrincipalSecret = $setupIdentity.ApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-M365Dsc @param -ErrorAction Stop
    Write-Host "Successfully connected to Azure environment '$envName'."

    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    $vms = Get-LabVM
    Write-Host "Imported lab '$($lab.Name)' with $($vms.Count) machines"

    if ((Get-LabVMStatus) -eq 'Stopped')
    {
        Write-Host "$($vms.Count) machine(s) are stopped. Starting them now."
        Start-LabVM -All -Wait
    }

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

        Install-Module -Name Microsoft365DSC -Force -AllowClobber -Scope AllUsers
        Set-M365DSCLoggingOption -IncludeNonDrifted $true
        [System.Environment]::SetEnvironmentVariable('BuildEnvironment', $args[0], 'Machine')

    } -ComputerName $vms -ArgumentList $lab.Notes.Environment

    # Generate client authentication certificate and upload it to the Azure application
    Remove-LabPSSession -All
    $s = New-LabPSSession -ComputerName $vms
    Add-FunctionToPSSession -Session $s -FunctionInfo (Get-Command -Name New-M365DSCSelfSignedCertificate)

    $certificate = Invoke-LabCommand -ComputerName $vms -ActivityName 'Generate client authentication certificate' -ScriptBlock {

        New-M365DSCSelfSignedCertificate -Subject M365DscLcmApplication -Store LocalMachine -PassThru

    } -PassThru

    if ($certificate.Count -gt 1)
    {
        Write-Error 'More than one certificate was generated. This is not expected. Please investigate.'
        return
    }

    $bytes = $certificate.Export('Cert')
    $params = @{
        keyCredentials = @(
            @{
                type        = 'AsymmetricX509Cert'
                usage       = 'Verify'
                key         = $bytes
                displayName = 'GeneratedByM365DscWorkshop'
            }
        )
    }

    $id = Get-M365DscIdentity -Name M365DscLcmApplication
    if (-not $id)
    {
        Write-Error "The application 'M365DscLcmApplication' does not exist. Please create it manually in the Azure portal and try again."
    }
    Write-Host "Updating application '$($id.DisplayName)' with new certificate (Thumbprint: $($certificate.Thumbprint))."
    Update-MgApplication -ApplicationId $id.Id -BodyParameter $params

    $identity = $environment.Identities | Where-Object Name -EQ 'M365DscLcmApplication'
    if ($identity.CertificateThumbprint -eq '<AutoGeneratedLater>')
    {
        $identity.CertificateThumbprint = $certificate.Thumbprint
    }

    Write-Host "Restarting $($vms.Count) machines."
    Restart-LabVM -ComputerName $vms -Wait

    Write-Host "Finished installing AzDo Build Agent on $($vms.Count) machines in environment '$envName'"

}

Write-Host "Updating the file '\source\Global\Azure\Azure.yml' to store certificate thumbprints."
$datum.Global.Azure | ConvertTo-Yaml | Out-File -FilePath $PSScriptRoot\..\source\Global\Azure.yml -Force

Write-Host "Committing and pushing the changes to the repository '$(git config --get remote.origin.url)'."
$currentBranchName = git rev-parse --abbrev-ref HEAD
git add ../source/Global/Azure.yml
git commit -m 'Tenant Update' | Out-Null
git push --set-upstream origin $currentBranchName | Out-Null

Write-Host 'Agent setup completed.' -ForegroundColor Green
