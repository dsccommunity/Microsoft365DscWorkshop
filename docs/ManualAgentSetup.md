# 1. Manually setting up the Azure DevOps Build Agent

The Azure DevOps agent setup for this solution can fully automated with the script [](../lab/31%20Agent%20Setup.ps1). The automation is based on [AutomatedLab](https://automatedlab.org/) which sometimes conflicts with security guidelines in production environments. The guide is for setting up the build agent without the scripts provided.

- [1. Manually setting up the Azure DevOps Build Agent](#1-manually-setting-up-the-azure-devops-build-agent)
  - [1.1. Connect to and prepare the Azure Tenant](#11-connect-to-and-prepare-the-azure-tenant)
  - [1.2. Create the User Assigned Identity](#12-create-the-user-assigned-identity)
  - [1.3. Assigning permissions](#13-assigning-permissions)
  - [1.4. Connect to and prepare Exchange Online](#14-connect-to-and-prepare-exchange-online)
  - [1.5. Prepare the VM](#15-prepare-the-vm)

To setup the build agent for an environment manually without the script provided, make sure you have

- A virtual machine in Azure with Windows Server 2022.
- This machine needs network connectivity to Azure DevOps (https://dev.azure.com).
- It also needs network connectivity to configure the respective tenant.

> :information_source: Note: This guide assumes you are installing the agent for the production tenant. Please change the commands if you deploy for a different tenant.

> :information_source: Note: This guide explains how to assign read-only permissions to the Azure DevOps build agent's managed identity as well as full permissions. Please change the command depending of that permissions you want to have the build agent.

---

## 1.1. Connect to and prepare the Azure Tenant

1. :pencil2: First connect to graph using your global admin account

```powershell
$scopes = 'RoleManagement.ReadWrite.Directory',
    'Directory.ReadWrite.All',
    'Application.ReadWrite.All',
    'Group.ReadWrite.All',
    'GroupMember.ReadWrite.All',
    'User.ReadWrite.All'
Connect-MgGraph -Scopes $scopes
```

2. :pencil2: Connect to the Azure tenant using the cmdlet `Connect-AzAccount` and using your global admin account

## 1.2. Create the User Assigned Identity

3. :pencil2: Create a new Azure User Assigned Identity using the following commands:

```powershell
$id = New-AzUserAssignedIdentity -Name LcmNew365ProdRO -ResourceGroupName M365DSCWorker -Location GermanyWestCentral
```

4. :pencil2: Then assign it to the virtual machine that you want to become an Azure DevOps build worker:

```powershell
$vm = Get-AzVM -ResourceGroupName M365DSCWorker -Name LcmNew365ProdRO
Update-AzVM -ResourceGroupName M365DSCWorker -VM $vm -IdentityType UserAssigned -IdentityId $id.Id
```

## 1.3. Assigning permissions

5. :pencil2: Then get the principal in Graph and add it to the `Global Reader` role

```powershell
$appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'LcmNew365ProdRO'"
$roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Global Reader'"
New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId "/"
```

Add the Graph permissions required by Microsoft365DSC for read-only or read/write access to the tenant:

6. :pencil2: First we need to start the build script which prepares the PowerShell sessions and amends the `PSModulePath` so the Microsoft365DSC module is available to the PowerShell session. The script also installs the required modules and sets up the required environment variables:

```powershell
.\build.ps1 -tasks noop
```

7. :pencil2: Next we need to import the `AzHelper` module:

```powershell
Import-Module -Name .\lab\AzHelpers.psm1
```

8. :pencil2: Then we get the desired permissions for the tenant (in the following case read-only):

```powershell
$requiredPermissions = Get-M365DSCCompiledPermissionList2 -AccessType Read
```

9. :pencil2: Then set the permissions on the previously created principal

```powershell
Set-ServicePrincipalAppPermissions -DisplayName ProdLcm -Permissions $requiredPermissions
```

You may want to double check the permissions are set correctly in the Azure portal or run the command

```powershell
Get-ServicePrincipalAppPermissions -DisplayName LcmNew365ProdRO
```

---

## 1.4. Connect to and prepare Exchange Online

10. :pencil2: Now connect to Exchange Online using the global admin account

```powershell
Connect-ExchangeOnline
```

11. :pencil2: Create a service principal for the Exchange Online connection

```powershell
$appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'LcmNew365ProdRO'"
$servicePrincipal = New-ServicePrincipal -AppId $appPrincipal.AppId -ObjectId $appPrincipal.Id -DisplayName LcmNew365ProdRO
```

12. :pencil2: Assign to the service principal the `View-Only Configuration` role

```powershell
New-ManagementRoleAssignment -App $servicePrincipal.AppId -Role "View-Only Configuration"
```

13. :pencil2: We are done, you can disconnect from Exchange Online.

```powershell
Disconnect-ExchangeOnline -Confirm:$false
```

---

## 1.5. Prepare the VM

On the VM we need to install some software and the Azure DevOps Build Worker. Then we connect the Azure DevOps Build Agent service to your Azure DevOps organization.

Install Software inside the Build Agent machine and connect it to Azure DevOps

14. :pencil2: Logon to the VM that you have dedicated as the Azure DevOps Worker with Remote Desktop.

15. :pencil2: Install the following software on the VM:
   - Install PowerShell 7
   - Install Git (only required for debugging)
   - Install Visual Studio Code with the PowerShell extension (only required for debugging)

16. :pencil2: Please download the Azure DevOps Agent (Windows x64) from the [GitHub Release](https://github.com/microsoft/azure-pipelines-agent/releases) page.

17. :pencil2: Then extract the zip file like this (please change the path according to your needs), set an environment variable and connect the build agent service to your Azure DevOps organization.

```powershell
Unblock-File -Path .\Downloads\vsts-agent-win-x64-3.240.1.zip

Expand-Archive -Path .\Downloads\vsts-agent-win-x64-3.240.1.zip -DestinationPath C:\ProdAgent1
```

18. :pencil2: Create the system-wide environment variable `BuildEnvironment`. It stores the name of the environment for which the build agent is set up. The variable is added as a [build agent capability](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=yaml%2Cbrowser) in Azure DevOps and allows the Azure DevOps pipeline to select the correct worker for each environment.

```powershell
[System.Environment]::SetEnvironmentVariable('BuildEnvironment', 'Prod', 'Machine')
```

Now it is time to connect the build agent service to your Azure DevOps organization.

19. :pencil2: Please follow the guide [Register an agent using a personal access token (PAT)](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/personal-access-token-agent-registration?view=azure-devops) and create a personal access token.

20. :pencil2: Connect the build agent service to your Azure DevOps organization using the following commands:

```powershell
$pat = '<PAT>'
C:\ProdAgent1\config.cmd --unattended --url https://dev.azure.com/<YourOrganizationName> --auth pat --token $pat --pool DSC --agent $env:COMPUTERNAME --runAsService --windowsLogonAccount 'NT AUTHORITY\SYSTEM' --acceptTeeEula
```

21. :pencil2: Then update the `NuGet` provider and the `PowerShellGet` module with these two commands:

```powershell
Install-PackageProvider -Name NuGet -Force
Install-Module -Name PowerShellGet -Force
```

22. :pencil2: Please check the Azure DevOps Agent Pool to see if the new worker appears there. Please also check its capabilities. There should be a capability named `BuildEnvironment` with the value `Prod`.

---

Now your Azure DevOps Build Worker is ready and accepts jobs from the pipeline for the respective environment.