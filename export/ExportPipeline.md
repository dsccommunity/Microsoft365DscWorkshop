# 1. Exporting the tenant data in a Azure DevOps pipeline

- [1. Exporting the tenant data in a Azure DevOps pipeline](#1-exporting-the-tenant-data-in-a-azure-devops-pipeline)
  - [1.1. Overview](#11-overview)
  - [1.2. Why Use Azure DevOps Pipelines for Tenant Export?](#12-why-use-azure-devops-pipelines-for-tenant-export)
    - [1.2.1. **Consistency and Reliability**](#121-consistency-and-reliability)
    - [1.2.2. **Security and Compliance**](#122-security-and-compliance)
    - [1.2.3. **Automation and Scheduling**](#123-automation-and-scheduling)
    - [1.2.4. **Scalability and Performance**](#124-scalability-and-performance)
    - [1.2.5. **Version Control and Change Management**](#125-version-control-and-change-management)
    - [1.2.6. **Monitoring and Alerting**](#126-monitoring-and-alerting)
    - [1.2.7. **Collaboration and Team Access**](#127-collaboration-and-team-access)
    - [1.2.8. **Cost Efficiency**](#128-cost-efficiency)
    - [1.2.9. **Disaster Recovery and Business Continuity**](#129-disaster-recovery-and-business-continuity)
    - [1.2.10. **Compliance and Governance**](#1210-compliance-and-governance)
  - [1.3. Implementation Considerations](#13-implementation-considerations)
    - [1.3.1. Prerequisites](#131-prerequisites)
    - [1.3.2. Best Practices](#132-best-practices)
  - [1.4. Conclusion](#14-conclusion)
  - [1.5. Create a VM in Azure](#15-create-a-vm-in-azure)
  - [1.6. Setup the Agent Pool in Azure DevOps](#16-setup-the-agent-pool-in-azure-devops)
  - [1.7. Create a Personal Access Token](#17-create-a-personal-access-token)
  - [1.8. Configure the VM](#18-configure-the-vm)
    - [Required Software](#required-software)
    - [The Azure Authentication Certificate](#the-azure-authentication-certificate)
  - [1.9. Connecting the worker with Azure DevOps](#19-connecting-the-worker-with-azure-devops)
  - [Creating the Pipeline in Azure DevOps](#creating-the-pipeline-in-azure-devops)
  - [Examine the created Artifacts](#examine-the-created-artifacts)

---

This guide explains how to run the steps outlined in [Export your Azure Tenant Configuration to Yaml or Json](ExportToYaml.md) in a Azure DevOps release pipeline.

<details>
<summary>

> ## :information_source: Details: Why running this task in a Azure DevOps release pipeline?

</summary>

## 1.1. Overview

This paragraph outlines the benefits and rationale for running Microsoft 365 tenant configuration exports through Azure DevOps (AzDo) pipelines rather than executing them directly from administrator workstations.

## 1.2. Why Use Azure DevOps Pipelines for Tenant Export?

### 1.2.1. **Consistency and Reliability**

- **Standardized Environment**: Pipelines run in controlled, consistent environments with predictable configurations
- **Dependency Management**: All required PowerShell modules and dependencies are automatically installed and versioned
- **Reproducible Results**: Every export runs with the same tools, versions, and environment variables
- **Reduced "Works on My Machine" Issues**: Eliminates variations caused by different admin workstation configurations

### 1.2.2. **Security and Compliance**

- **Centralized Authentication**: Uses managed identities or service principals with properly scoped permissions
- **No Local Credential Storage**: Eliminates the risk of credentials being stored on individual admin machines
- **Audit Trail**: Complete logging and tracking of who initiated exports and when they occurred
- **Access Control**: Pipeline execution can be restricted to authorized personnel through Azure DevOps permissions
- **Secrets Management**: Sensitive information is stored securely in Azure Key Vault and accessed through secure pipeline variables

### 1.2.3. **Automation and Scheduling**

- **Scheduled Exports**: Automatic execution on a regular schedule (daily, weekly, monthly)
- **Event-Driven Exports**: Trigger exports based on specific events or changes in the tenant
- **Unattended Operation**: No need for an administrator to be present during export execution
- **Parallel Processing**: Can run multiple exports simultaneously or in sequence without manual intervention

### 1.2.4. **Scalability and Performance**

- **Dedicated Resources**: Pipeline agents provide dedicated compute resources for export operations
- **Parallel Execution**: Multiple tenants or configuration sections can be exported concurrently
- **Resource Optimization**: Pipeline agents are automatically provisioned and deprovisioned as needed
- **No Impact on Admin Workstations**: Export operations don't consume local machine resources

### 1.2.5. **Version Control and Change Management**

- **Automatic Commits**: Export results are automatically committed to source control
- **Change Tracking**: Git history provides complete visibility into configuration changes over time
- **Branching Strategy**: Exports can be committed to specific branches for review before merging
- **Pull Request Integration**: Configuration changes can trigger automated reviews and approvals

### 1.2.6. **Monitoring and Alerting**

- **Pipeline Notifications**: Automatic alerts when exports succeed, fail, or encounter issues
- **Integration with Monitoring Tools**: Export status can be integrated with existing monitoring solutions
- **Error Handling**: Structured error reporting and automatic retry mechanisms
- **Performance Metrics**: Track export duration, success rates, and resource utilization

### 1.2.7. **Collaboration and Team Access**

- **Shared Infrastructure**: Multiple team members can benefit from the same export infrastructure
- **No Single Point of Failure**: Not dependent on a specific administrator's machine being available
- **Team Visibility**: All team members can view export status and results through the Azure DevOps interface
- **Knowledge Sharing**: Pipeline configuration serves as documentation for the export process

### 1.2.8. **Cost Efficiency**

- **Resource Utilization**: Pipeline agents are only consumed during export execution
- **No Dedicated Hardware**: Eliminates the need for always-on administrator workstations
- **Shared Resources**: Multiple projects and teams can share the same pipeline infrastructure
- **Automated Cleanup**: Temporary resources are automatically cleaned up after export completion

### 1.2.9. **Disaster Recovery and Business Continuity**

- **Geographic Distribution**: Pipeline agents can run in different regions for redundancy
- **Backup and Recovery**: Export data is automatically backed up through source control
- **Service Independence**: Not dependent on specific administrator availability or workstation health
- **Rapid Recovery**: Export processes can be quickly restored and resumed in case of issues

### 1.2.10. **Compliance and Governance**

- **Audit Requirements**: Automated logging satisfies compliance requirements for change tracking
- **Regulatory Compliance**: Structured processes meet regulatory requirements for configuration management
- **Data Retention**: Historical export data is retained according to organizational policies
- **Approval Workflows**: Can integrate with approval processes for sensitive tenant exports

## 1.3. Implementation Considerations

### 1.3.1. Prerequisites

- Azure DevOps organization with appropriate permissions
- Service principal or managed identity with necessary Microsoft 365 permissions
- Azure Key Vault for secure credential storage
- Git repository for storing export results

### 1.3.2. Best Practices

1. **Use Managed Identities**: Prefer managed identities over service principals when possible
2. **Implement Proper Scoping**: Grant minimum required permissions to the export service account
3. **Schedule Appropriately**: Avoid peak usage hours for large tenant exports
4. **Monitor Resource Usage**: Track pipeline agent consumption and optimize as needed
5. **Implement Error Handling**: Include retry logic and proper error reporting
6. **Version Control Strategy**: Use meaningful commit messages and branch protection rules

## 1.4. Conclusion

Running tenant configuration exports through Azure DevOps pipelines provides significant advantages in terms of security, reliability, automation, and governance compared to manual execution from administrator workstations. This approach aligns with Infrastructure as Code (IaC) best practices and enables organizations to maintain consistent, auditable, and scalable configuration management processes.
</details>

## 1.5. Create a VM in Azure

Create a VM in Azure or another virtualization platform. It is important that this VM has full network access to Azure. In Azure, the size `Standard D4s v6 (4 vcpus, 16 GiB memory)` is more then enough.

## 1.6. Setup the Agent Pool in Azure DevOps

While the VM is being created, we are moving on configuring the Azure DevOps project.

Please create a new agent pool within the Azure DevOps project named `DSC` in the `Project settings`. The pool type should be `Self-hosted`. Please check the box `Grant access permission to all pipelines`.

## 1.7. Create a Personal Access Token

Create a personal access token with the following scopes and keep it for a later step:

- Agent Pools -> Read & manage
- Code -> Read

## 1.8. Configure the VM

### Required Software

To make the setup process as easy as possible, we use [Chocolatey](https://chocolatey.org/install) for installing the required software. Please run the following code block on the VM:

```powershell
#Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

#Install PowerShell 7
choco install powershell-core -y

#Install the Azure DevOps Agent
choco install azure-pipelines-agent -y

#Install Git
choco install git.install -y

#Set the build environment for the build agent
[System.Environment]::SetEnvironmentVariable('buildEnvironment', 'Dev', 'Machine')
```

### The Azure Authentication Certificate

When setting up the project you created a self-signed certificate and uploaded the public key to the Azure App Registration. The certificate including the private key must be installed on the Azure DevOps Agent VM.

- Please export the certificate including the private key.
- Install the exported certificate (*.pfx) on the VM in the machine for the local computer and not just the user.

You can verify if the certificate exist on the aggent VM by running this command:

```powershell
dir Cert:\LocalMachine\My\ | Where-Object Subject -eq 'CN=M365DSC Export'
```

The command should return the certificate like this:

```text
   PSParentPath: Microsoft.PowerShell.Security\Certificate::LocalMachine\My

Thumbprint                                Subject              EnhancedKeyUsageList
----------                                -------              --------------------
446FD17A85129124785296B39CF5D4C46DA718C2  CN=M365DSC Export    {Client Authentication, Server Authentication}
```

## 1.9. Connecting the worker with Azure DevOps

Connecting the Azure Build Agent requires only one line. Please replace the `url` parameter with the Azure DevOps organization like and the parameter `token` with the personal access token, that you have previously created.

```powershell
.\config.cmd --unattended --url https://dev.azure.com/randre/ --auth pat --token 5JmTfeNGCwp3LN... --pool DSC --agent Worker1 --runasservice --windowsLogonAccount 'NT AUTHORITY\SYSTEM'
```

The output of the command should look like this:

```text

  ___                      ______ _            _ _
 / _ \                     | ___ (_)          | (_)
/ /_\ \_____   _ _ __ ___  | |_/ /_ _ __   ___| |_ _ __   ___  ___
|  _  |_  / | | | '__/ _ \ |  __/| | '_ \ / _ \ | | '_ \ / _ \/ __|
| | | |/ /| |_| | | |  __/ | |   | | |_) |  __/ | | | | |  __/\__ \
\_| |_/___|\__,_|_|  \___| \_|   |_| .__/ \___|_|_|_| |_|\___||___/
                                   | |
        agent v4.258.1             |_|          (commit 8292055)


>> Connect:

Connecting to server ...

>> Register Agent:

Scanning for tool capabilities.
Connecting to the server.
Successfully added the agent
Testing agent connection.
2025-08-02 21:10:52Z: Settings Saved.
Error reported in diagnostic logs. Please examine the log for more details.
    - C:\agent\_diag\Agent_20250802-211046-utc.log
Granting file permissions to 'NT AUTHORITY\SYSTEM'.
Service vstsagent.randre.DSC.Worker1 successfully installed
Service vstsagent.randre.DSC.Worker1 successfully set recovery option
Service vstsagent.randre.DSC.Worker1 successfully set to delayed auto start
Service vstsagent.randre.DSC.Worker1 successfully configured
Service vstsagent.randre.DSC.Worker1 started successfully
```

## Creating the Pipeline in Azure DevOps

- Go to the pipelines pane
- There, click the button `New pipeline`
- Select the source `Azure Repos Git` and then select the repo.
- You have to create the default pipeline `azure-pipelines.yml` first before being able to create any other one.
- As you likely don't want to trigger a build, click the little arrow right to the `Run` button and select `Save`.

Now you create the export pipeline:

- Go back to the pipelines main menu and click the button `New pipeline` again
- Again please select the source `Azure Repos Git` and then select the repo.
- Now you have the option to select an `Existing Azure Pipleines YAML file`.
- On the right and pane, select the file `/pipelines/export.yml`.
- Click the little arrow right to the `Run` button and select `Save` again.
- The pipeline should have been created but with an unexpected name. Click on the 3 dots in the upper right corner and rename it to `Export`.

Now everything should be ready to run the export task in the Azure DevOps pipeline.

- Please click on `Run pipeline`.
- In the next dialog, remove the environments Test and Prod from the parameter `buildEnvironments`.
- Click the `Run` button.

## Examine the created Artifacts

If a pipeline creates something, it is called an artifact. If the pipeline did run successfully, there should be `1 published` artifact. You can expand it and should find `*.ps1`, `*.psd1`, `*.mof` and `*.yml` files. The yaml files are the ones that contain the exported and converted data.
