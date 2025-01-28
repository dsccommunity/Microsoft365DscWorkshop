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
$environments = $datum.Global.Azure.Environments.Keys

if ($datum.Global.ProjectSettings.BuildAgents.Password -eq '<Password>' -or $null -eq $datum.Global.BuildAgents.Password)
{
    $defaultPassword = 'Somepass1'
    $password = Read-Host -Prompt 'Enter the password for the build agents or press <Enter> to use the default password (Somepass1)'

    if ($password -eq '')
    {
        $datum.Global.ProjectSettings.BuildAgents.Password = $defaultPassword
    }
    else
    {
        $datum.Global.ProjectSettings.BuildAgents.Password = $password
    }
    if ($datum.Global.ProjectSettings.PersonalAccessToken -ne '<PersonalAccessToken>')
    {
        $pass = $datum.__Definition.DatumHandlers.'Datum.ProtectedData::ProtectedDatum'.CommandOptions.PlainTextPassword | ConvertTo-SecureString -AsPlainText -Force
        $datum.Global.ProjectSettings.PersonalAccessToken = $datum.Global.ProjectSettings.PersonalAccessToken | Protect-Datum -Password $pass -MaxLineLength 9999
    }
    $datum.Global.ProjectSettings | ConvertTo-Yaml | Out-File $PSScriptRoot\..\source\Global\ProjectSettings.yml
}

if ((git status -s) -like '*source/Global/ProjectSettings.yml')
{
    git add $PSScriptRoot\..\source\Global\ProjectSettings.yml
    git commit -m 'Updated Azure DevOps Build Agent Data' | Out-Null
    git push | Out-Null
}

if ($EnvironmentName)
{
    Write-Host "Filtering environments to: $($EnvironmentName -join ', ')" -ForegroundColor Magenta
    $environments = $environments | Where-Object { $EnvironmentName -contains $_ }
}
Write-Host "Setting up environments: $($environments -join ', ')" -ForegroundColor Magenta

foreach ($envName in $environments)
{
    $environment = $datum.Global.Azure.Environments.$envName
    $setupIdentity = $environment.Identities | Where-Object Name -EQ M365DscSetupApplication
    Write-Host "Testing connection to environment '$envName'" -ForegroundColor Magenta

    $param = @{
        TenantId               = $environment.AzTenantId
        TenantName             = $environment.AzTenantName
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $setupIdentity.ApplicationId
        ServicePrincipalSecret = $setupIdentity.ApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }

    Connect-M365Dsc @param -ErrorAction Stop

    Test-M365DscConnection -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop
}

foreach ($envName in $environments)
{
    $environment = $datum.Global.Azure.Environments.$envName
    Write-Host "Working in environment '$envName'" -ForegroundColor Magenta
    $notes = @{
        Environment = [string]$envName
    }

    $setupIdentity = $environment.Identities | Where-Object Name -EQ M365DscSetupApplication
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

    Write-Host "Creating lab for environment '$envName' in the subscription."
    New-LabDefinition -Name "$($datum.Global.ProjectSettings.ProjectName)$($envName)" -DefaultVirtualizationEngine Azure -Notes $notes

    Add-LabAzureSubscription -SubscriptionId $environment.AzSubscriptionId -DefaultLocation $datum.Global.ProjectSettings.BuildAgents.AzureLocation

    Sync-LabAzureLabSources

    Set-LabInstallationCredential -Username $datum.Global.ProjectSettings.BuildAgents.UserName -Password $datum.Global.ProjectSettings.BuildAgents.Password

    $PSDefaultParameterValues = @{
        'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
        'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    }

    Add-LabDiskDefinition -Name "Lcm$($datum.Global.ProjectSettings.ProjectName)$($envName)Data1" -DiskSizeInGb 250 -Label Data

    Add-LabMachineDefinition -Name "Lcm$($datum.Global.ProjectSettings.ProjectName)$($envName)" -AzureRoleSize $datum.Global.ProjectSettings.BuildAgents.AzureRoleSize -DiskName "Lcm$($datum.Global.ProjectSettings.ProjectName)$($envName)Data1"

    Install-Lab

    Write-Host "Finished creating lab for environment '$envName'."

    Checkpoint-LabVM -All -SnapshotName AfterInstall

    Write-Host "Created snapshot 'AfterInstall' for lab '$($datum.Global.ProjectSettings.ProjectName)$($envName)'."

}

Write-Host "Finished creating all labs VMs for the project '$($datum.Global.ProjectSettings.ProjectName)'" -ForegroundColor Green

# ------------------------------------------------------------------------------------------------------------

Write-Host 'Starting to assign managed identity to VMs and set permissions for Microsoft365DSC workloads' -ForegroundColor Green
$labs = Get-Lab -List | Where-Object { $_ -Like "$($datum.Global.ProjectSettings.ProjectName)*" }
foreach ($lab in $labs)
{
    $lab -match "(?:$($datum.Global.ProjectSettings.ProjectName))(?<Environment>\w+)" | Out-Null
    $envName = $Matches.Environment
    if ($EnvironmentName -and $envName -notin $EnvironmentName)
    {
        Write-Host "Skipping environment '$envName'" -ForegroundColor Yellow
        continue
    }

    $environment = $datum.Global.Azure.Environments."$envName"
    $setupIdentity = $environment.Identities | Where-Object Name -EQ M365DscSetupApplication

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
    $resourceGroupName = $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName
    Write-Host "Working in lab '$($lab.Name)' with environment '$envName'"

    if (-not ($id = Get-AzUserAssignedIdentity -Name "Lcm$($datum.Global.ProjectSettings.ProjectName)$envName" -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue))
    {
        Write-Host "Managed Identity not found, creating it named 'Lcm$($datum.Global.ProjectSettings.ProjectName)$($envName)'"
        $id = New-AzUserAssignedIdentity -Name "Lcm$($datum.Global.ProjectSettings.ProjectName)$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Location $lab.AzureSettings.DefaultLocation.Location
    }

    $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name "Lcm$($datum.Global.ProjectSettings.ProjectName)$envName"
    if ($vm.Identity.UserAssignedIdentities.Keys -eq $id.Id)
    {
        Write-Host "Managed Identity already assigned to VM 'Lcm$($datum.Global.ProjectSettings.ProjectName)$($lab.Notes.Environment)' in environment '$envName'"
    }
    else
    {
        Write-Host "Assigning Managed Identity to VM 'Lcm$($datum.Global.ProjectSettings.ProjectName)$($lab.Notes.Environment)' in environment '$envName'"
        Update-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityId $id.Id | Out-Null
    }

    $azIdentity = New-M365DscIdentity -Name "Lcm$($datum.Global.ProjectSettings.ProjectName)$envName" -PassThru
    Write-Host "Setting permissions for managed identity 'Lcm$($datum.Global.ProjectSettings.ProjectName)$envName' in environment '$envName'"
    Add-M365DscIdentityPermission -Identity $azIdentity -AccessType Update

    $vm = Get-LabVM

    Invoke-LabCommand -ComputerName $vm -ScriptBlock {
        Set-Item -Path WSMan:\localhost\MaxEnvelopeSizekb -Value 8192
    } -ActivityName 'Setting WSMan MaxEnvelopeSizekb to 8192 for VMs in environment'
}

Write-Host 'Finished assigning managed identity to VMs and setting permissions for Microsoft365DSC workloads' -ForegroundColor Green

Write-Host 'All done.'
