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

To understand how the `AADGroup` resource should be use, let's have a look at its syntax:

```powershell
Get-DscResource -Name AADGroup -Syntax
```

The mandatory properties are not in square bracket, so now we know what information we have to provide.

## Create your first (or second) Microsoft365DSC configuration

We want to create a DSC configuration that controls a group in Entra ID. Please create the file `DscAATestGroup.ps1` in the project folder.

Based on the syntax we have just retrieved, the configuration could look like this:

> Note that the DSC resource module `Microsoft365DSC` must be imported. There is no auto-loading.

```powershell
configuration TestGroupDemo
{
    Import-DscResource -ModuleName Microsoft365DSC

    node localhost {

        AADGroup TestGroupDsc
        {
            DisplayName = 'Test Group Dsc'
            MailEnabled = $false
            MailNickname = 'TestGroupDsc'
            SecurityEnabled = $true
        }
    }
}
```

The we are compiling the configuration like we did with the previous one.

```powershell
TestGroupDemo -OutputPath C:\DSC
```

Please verify if the MOF file has been created successfully. If it has, let's instruct the LCM:

```powershell
Start-DscConfiguration -Path C:\DSC\ -Wait -Verbose -Force
```

The configuration should not work and give you this error:

```text
InvalidOperation: PowerShell DSC resource MSFT_AADGroup  failed to execute Test-TargetResource functionality with error message: You must specify either the Credential or ApplicationId, TenantId and CertificateThumbprint parameters.
```

## Adding the Tenant Data and Credentials

Of course, the configuration could not work without knowing in which tenant to create the group and how to authenticate in this tenant. So let's add the missing data.

Run the command `Get-DscResource -Name AADGroup -Syntax` again identify the properties we can use.

The properties the `AADGroup` resource and all other Microsoft365DSC resources provide for authentication are these ones:

```text
[TenantId = [string]]
[ManagedIdentity = [bool]]
[AccessTokens = [string[]]]
[ApplicationId = [string]]
[ApplicationSecret = [PSCredential]]
[CertificateThumbprint = [string]]
```

Considering that we want to authenticate with an application and an application secret, we need to define the `TenantId` and `ApplicationSecret`. As the `ApplicationSecret` is of the type `PSCredential`, we need to create such an object first.

Pease add this line to the configuration. It should be before the resource. Don't forget to replace the placeholder for the secret with the secret your retrieved from your account information yaml file.

```powershell
$cred = [pscredential]::new('empty', ('ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMN' | ConvertTo-SecureString -AsPlainText -Force))
```

Then extend the resource properties by `TenantId`, `ApplicationId` and `ApplicationSecret`. All the data is in the account information yaml file.

```powershell
AADGroup TestGroupDsc
{
    DisplayName = 'Test Group Dsc'
    MailEnabled = $false
    MailNickname = 'TestGroupDsc'
    SecurityEnabled = $true
    TenantId = 'MngEnvMCAP167509.onmicrosoft.com'
    ApplicationId = 'df6ae811-e8b1-466d-a51f-976807a96c06'
    ApplicationSecret = $cred
}
```

Ok, now it is time to compile the configuration again and then hand it over to the LCM:

```powershell
TestGroupDemo -OutputPath C:\DSC
Start-DscConfiguration -Path C:\DSC\ -Wait -Verbose -Force
```

The next error appears:

```text
System.InvalidOperationException error processing property 'ApplicationSecret' OF TYPE 'AADGroup': Converting and storing encrypted passwords as plain text is not recommended. For more information on securing credentials in MOF file, please refer to MSDN blog: http://go.microsoft.com/fwlink/?LinkId=393729
```

## Secure DSC Credentials Handling

The error occurs because the DSC configuration is trying to store the `ApplicationSecret` as plain text in the MOF file, which is insecure and blocked by default.

> Note: Avoid hardcoding secrets in scripts if possible. If secrets have to be provided like in this case, use secure methods like `Get-Credential` or retrieve secrets from a secure vault. If secrets have to be stored in the MOF file, encrypt them with a certificate.
> - [Credentials Options in Configuration Data](https://learn.microsoft.com/en-us/powershell/dsc/configurations/configdatacredentials?view=dsc-1.1)
> - [Dsc Configuration Data Encryption Done Right](https://janhendrikpeters.de/post/dsc-configuration-data-encryption-done-right/)

## <u>Unsecure</u> DSC Credentials Handling

In this case we are ok with having the credentials in plain text in the MOF file. To convince DSC of tolerating unencrypted credentials, 
