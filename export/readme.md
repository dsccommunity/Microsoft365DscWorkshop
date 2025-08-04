# 1. Export your Azure Tenant Configuration

- [1. Export your Azure Tenant Configuration](#1-export-your-azure-tenant-configuration)
  - [1.1. Preparations on your Local Machine](#11-preparations-on-your-local-machine)
    - [1.1.1. Forking or importing the Project](#111-forking-or-importing-the-project)
    - [1.1.2. Cloning the Project](#112-cloning-the-project)
    - [1.1.3. Downloading Dependencies](#113-downloading-dependencies)
  - [1.2. Configuring the Azure Tenant](#12-configuring-the-azure-tenant)
  - [1.3. Data Conversion to Yaml or Json](#13-data-conversion-to-yaml-or-json)

---

For exporting your tenant configuration with [Microsoft365DSC](https://microsoft365dsc.com/) there is not much required. The following lines will guide you through.

> :warning: You must be a local administrator one the machine you run the setup scripts on.

## 1.1. Preparations on your Local Machine

### 1.1.1. Forking or importing the Project

For this project to work it is required to change the content of some files. Hence, it is required to create yourself a
writable copy of the project. Either you do a fork on GitHub or you import the content of this project into a project
you host on a developer platform or code management solution of your choice.

This guide expects you have created a new project on Azure DevOps and imported the content from here. Alternatively, you can create a fork on GitHub, but then some scripts won't work and you have to make the required tasks manually.

### 1.1.2. Cloning the Project

> :warning: Do not download the project as a Zip file. The build process will not work if you don't clone the project.

Clone the project in Visual Studio Code Source Control Activity Bar or use the command `git.exe`. With the following command you clone the Git repository to your local machine. **Please change the link according to your fork / project on your code management solution.**

```powershell
git clone https://github.com/dsccommunity/Microsoft365DscWorkshop.git C:\Git
```

### 1.1.3. Downloading Dependencies

1. The project has a lot of dependencies that will all be downloaded automatically for you. For that, please run the build script like this:

> :information_source: If you want to know the number of dependencies, this command will tell you: `(Import-PowerShellDataFile -Path .\RequiredModules.psd1).Count - 1`

```powershell
.\build.ps1 -UseModuleFast -ResolveDependency -Tasks noop
````

> :information_source: 'noop' means 'no operation'

1. After having all dependencies downloaded, you are ready to start the work. First you need to initialize the shell to access all required resources. The `Microsoft365DscWorkshop` repository provides some useful functions. To make them available, run the task `init`:

```powershell
.\build.ps1 -Tasks init
```

## 1.2. Configuring the Azure Tenant

1. In order to read from the Azure tenant, you need to create an application. In order to do that, you need to connect to it with a global administrator. Please change the arguments according to you environment.

```powershell
Connect-M365Dsc -TenantId b246c1af-87ab-41d8-9812-83cd5ff534cb -TenantName MngEnvMCAP576786.onmicrosoft.com -SubscriptionId 9522bd96-d34f-4910-9667-0517ab5dc595
```

1. Create a app registration in the tenant you want to export with this command:

```powershell
$id = New-M365DscIdentity -Name M365DscExportApplication -PassThru
```

2. Create a certificate and upload it to the app registration.

   1. Use the cmdlet `New-M365DSCSelfSignedCertificate` to generate a self-signed certificate that will be stored in your machines certificate store:

   ```powershell
   $cert = New-M365DSCSelfSignedCertificate -Store LocalMachine -Subject 'M365DSC Export' -PassThru
   ```

   2. The public part of the certificate must be added to the previously created application in order to be able authenticate with it. Please add the public key to the application in Azure with the following commands.

   ```powershell
   $certParam = @{
         Type = "AsymmetricX509Cert"
         Usage = "Verify"
         Key = $cert.RawData
   }

   Update-MgApplication -ApplicationId $id.Id -KeyCredentials $certParam
   ```

   3. The application does not yet have the necessary permissions to access all resource in Azure. the following commands will add the permissions.

   ```powershell
   $permissions = Get-M365DSCCompiledPermissionList2 -AccessType Read
   Set-ServicePrincipalAppPermissions -DisplayName M365DscExportApplication -Permissions $permissions
   ```

Now everything should be setup to run the export. To test this, please run the following command to test the export of applications. Change the tenant ID, certificate thumbprint and application ID according to your environment.

>Note: If you have closed the PowerShell session in the meantime and PowerShell does not find the cmdlet `Export-M365DSCConfiguration` anymore, please run `.\build.ps1 -Tasks noop` to initialize the environment. The will amend the `PSModulePath` to include `$ProjectPath\output\RequiredModules\`.

```powershell
Export-M365DSCConfiguration -Components AADApplication -ApplicationId 40642b84-0d13-43ac-951e-8700d5be1131 -TenantId MngEnvMCAP576786.onmicrosoft.com -CertificateThumbprint FBA23F11CD8F78A17B9E2105D9BE3EE15BA04165 -Path .\temp\
```

## 1.3. Data Conversion to Yaml or Json

If you want the data in a different more transportable format, please refer to [Export your Azure Tenant Configuration to Yaml or Json](./ExportToYaml.md). In many scenarios, the PSD1 files are not helpful.

In [Exporting the tenant data in a Azure DevOps pipeline](./ExportPipeline.md) you will be guided to setup the export in an Azure DevOps Release Pipeline.
