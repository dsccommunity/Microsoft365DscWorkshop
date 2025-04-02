# Microsoft365DSC - A PowerShell-based DevOps tool for Microsoft 365 governance

**Microsoft365DSC** is an open-source PowerShell module that enables "Infrastructure as Code" (IaC) for Microsoft 365 environments. It allows administrators to define, automate, and enforce configurations for services like Teams, Exchange Online, SharePoint, and Security & Compliance using declarative PowerShell scripts. By exporting existing settings as reusable code, it ensures consistency across tenants, detects deviations (configuration drift), and automatically remediates them to maintain compliance.  

Built on PowerShell Desired State Configuration (DSC), the tool simplifies large-scale governance by integrating with DevOps pipelines. It’s ideal for organizations managing multiple Microsoft 365 tenants, auditing regulatory compliance, or rebuilding environments after disasters. Unlike manual portal-based management, Microsoft365DSC provides version-controlled, auditable, and repeatable automation for critical cloud workloads.  

It

- :wrench: Automates configurations (Teams, Exchange, SharePoint, etc.) as code.
- :lock_with_ink_pen: Enforces compliance & detects configuration drift.
- :arrows_counterclockwise: Exports/Deploys settings across tenants/environments.

The key benefit is:

- :100: Consistent, auditable control of Microsoft 365 at scale.

## What do we want to achieve?

In this task we want to create a DSC configuration that control a group in Entra ID. If someone deletes the group, DSC will recreate is.

## Getting started with [Microsoft365DSC](https://microsoft365dsc.com/)

First we need to install Microsoft365DSC. Please do so by calling in Windows PowerShell 5.1 and not PowerShell 7.

> :warning: The Local Configuration Manager runs a Windows PowerShell 5.1 runspace in the security context of the local machine. This is why the modules have to be installed in the `AllUsers` context in `C:\Program Files\WindowsPowerShell\Modules` and not `C:\Program Files\PowerShell\Modules`.

Start a Windows PowerShell 5.1 and run the following lines:

```powershell
$PSVersionTable #to check if you are in the right PowerShell
Install-Module -Name Microsoft365DSC -Scope AllUsers -Force
Update-M365DSCDependencies #this installs another ~30 modules to 'C:\Program Files\WindowsPowerShell\Modules'
```

## How does the DSC resource AADGroup work?



## Create your first (or second) Microsoft365DSC configuration

We want to create a DSC configuration that controls a group in Entra ID. Please create the file `DscAATestGroup.ps1` in the project folder.
