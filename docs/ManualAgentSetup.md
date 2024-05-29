# Manually setting up the Azure DevOps Build Agent

To setup the build agent for an environment manually without the script provided, make sure you have
- A virtual machine in Azure with Windows Server 2022.
- This machine needs network connectivity to Azure DevOps (https://dev.azure.com)
- It also needs network connectivity to configure the respective tenant

## Connect to your Azure Tenant

1. First connect to graph using your global admin account
```powershell
$scopes = 'RoleManagement.ReadWrite.Directory',
    'Directory.ReadWrite.All',
    'Application.ReadWrite.All',
    'Group.ReadWrite.All',
    'GroupMember.ReadWrite.All',
    'User.ReadWrite.All'
Connect-MgGraph -Scopes $scopes
```

1. Connect to the Azure tenant using the cmdlet `Connect-AzAccount` and using your global admin account

1. Create a new Azure User Assigned Identity.

```powershell
$id = New-AzUserAssignedIdentity -Name ProdLcm -ResourceGroupName ProdTest -Location GermanyWestCentral
Update-AzVM -ResourceGroupName ProdTest -VM $vm -IdentityType UserAssigned -IdentityId $id.Id
```

1. Then get the principal in Graph and add it to the Global Reader role

```powershell
$appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'ProdLcm'"
$roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Global Reader'"
New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/"
```

Add the Graph Permissions required by Microsoft365DSC for read-only access to the tenant

Firest we need to start the build script which prepares the PowerShell sessions and amends the PSModulePath so the Microsoft365DSC module is available to the PowerShell session. The script also installs the required modules and sets up the required environment variables.
.\build.ps1 -tasks noop

Next we need to import the AzHelper module
Import-Module -Name .\lab\AzHelpers.psm1

Then we get the read-only permissions for the tenant
$requiredPermissions = Get-M365DSCCompiledPermissionList2 -AccessType Read

And then we configure the permissions for the previously created principal
Set-ServicePrincipalAppPermissions -DisplayName ProdLcm -Permissions $requiredPermissions

You may want to double check the permissions are set correctly in the Azure portal.

------------------------------------

Now connect to Exchange Online using the global admin account

Connect-ExchangeOnline

Create a service principal for the Exchange Online connection
$appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'ProdLcm'"
$servicePrincipal = New-ServicePrincipal -AppId $appPrincipal.AppId -ObjectId $appPrincipal.Id -DisplayName ProdLcm

Assign to the service principal the View-Only Configuration role
New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "View-Only Configuration"

Disconnect-ExchangeOnline

------------------------------------

## Install Software inside the Build Agent machine and connect it to Azure DevOps

1. Please, logon to the VM that you have dedicated as the Azure DevOps Worker

1. Install the following software:
- Install Visual Studio Code with the PowerShell extension
- Install Git
- Install PowerShell 7

Please download the Azure DevOps Agent from the [GitHub Release](https://github.com/microsoft/azure-pipelines-agent/releases) page.

Then extract the zip file like this (please change the path according to your needs), set an environment variable and 

```powershell
Unblock-File -Path .\Downloads\vsts-agent-win-x64-3.240.1.zip

Expand-Archive -Path .\Downloads\vsts-agent-win-x64-3.240.1.zip -DestinationPath C:\ProdAgent1

[System.Environment]::SetEnvironmentVariable('BuildEnvironment', 'Prod', 'Machine')

$pat = '<PAT>'
C:\ProdAgent1\config.cmd --unattended --url https://dev.azure.com/<YourOrganizationName> --auth pat --token $pat --pool DSC --agent $env:COMPUTERNAME --runAsService --windowsLogonAccount 'NT AUTHORITY\SYSTEM' --acceptTeeEula

Install-PackageProvider -Name NuGet -Force
Install-Module -Name PowerShellGet -Force
```

1. Please check the Azure DevOps Agent Pool if the new worker appears there. Please also check for its capabilities. There should be a capability named `BuildEnvironment` with the value `Prod`
