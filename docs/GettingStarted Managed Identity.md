# 1. Getting started

- [1. Getting started](#1-getting-started)
  - [1.1. Preparing the project and the Azure Tenant](#11-preparing-the-project-and-the-azure-tenant)
    - [1.1.1. Cloning the Project](#111-cloning-the-project)
    - [1.1.5. Create a VM for the DSC Local Configuration Manager (LCM)](#115-create-a-vm-for-the-dsc-local-configuration-manager-lcm)
    - [Create Managed Identity](#create-managed-identity)
  - [1.2. Building the Artifacts](#12-building-the-artifacts)
    - [1.2.1. Set environment details in the DSC Configuration Data](#121-set-environment-details-in-the-dsc-configuration-data)
    - [1.2.2. Starting the Build process](#122-starting-the-build-process)
  - [1.3. Prepare the LCM Virtual Machine for the first DSC job](#13-prepare-the-lcm-virtual-machine-for-the-first-dsc-job)
    - [1.3.1. Importing the `DscWorker` certificate mapped to the `DscWorker` app](#131-importing-the-dscworker-certificate-mapped-to-the-dscworker-app)
    - [1.3.2. Installing requirements](#132-installing-requirements)
  - [1.4. Pushing the configuration](#14-pushing-the-configuration)
  - [1.5. Next steps](#15-next-steps)

## 1.1. Preparing the project and the Azure Tenant

The authentication of DSC against Azure is based on certificates. Certificates are stored in an Azure Key Vault to protect them and make them available for the release pipeline. The Key Vault can be in the same tenant that you want to control or in another one. For this walk-through, we are creating the Key Vault in a different tenant.

The build process and release pipeline has the certificate to authenticate against the tenant and access the Key Vault. From the Key Vault, the build pipeline can retrieve a certificate to authenticate against the tenant with global admin rights.

> :red_circle: This walk-through configures only 1 tenant. The concept is designed to configure as many tenants as you want. We are highlighting in the documentation when resources have to be created multiple times depending on the number of tenants.

We consider this single tenant we configure as the Dev environment. Other tenants to configure could be labeled Test and Production.

### 1.1.1. Cloning the Project

> :warning: Do not download the project as a Zip file. The build process will not work if you don't clone the project.

With the following command you clone the Git repository to your local machine.

```powershell
git clone https://raandree@dev.azure.com/raandree/M365DscWorkshop/_git/M365DscWorkshop C:\Git
```

We need some files from the repository to setup the resources in Azure.

### 1.1.5. Create a VM for the DSC Local Configuration Manager (LCM)

Each environment (tenant) will have its own LCM. The LCM is the engine that will enact the configuration and makes sure, that the tenant is in the desired state. For more information, refer to [Configuring the Local Configuration Manager](https://learn.microsoft.com/en-us/powershell/dsc/managing-nodes/metaconfig?view=dsc-1.1).

:ballot_box_with_check: Create a virtual machine in the tenant named `LcmDev`. The role size does not have to be huge, 2 cores and 8GB of RAM is fine.

> :information_source: The machine should be named `LcmDev` as this is the name of the node in the configuration data (see [LcmDev.yml](/source/AllNodes/Dev/LcmDev.yml))

### Create Managed Identity

Name like VM
Same resource group

Assign global admin role for now

Assign the managed identity to the vm


## 1.2. Building the Artifacts

What are the artifacts created in this project? DSC is a part of PowerShell but the DSC engine, the component which applies the configuration, does not understand native PowerShell instructions. The instructions must be translated into [MOF Files](https://learn.microsoft.com/en-us/windows/win32/wmisdk/managed-object-format--mof-). The build pipeline provided in this project creates all required artifacts.

### 1.2.1. Set environment details in the DSC Configuration Data

The file [\source\Global\Azure.yml](/source//Global/Azure.yml) contains the data about all the Azure tenants you want to configure. It also assigns the tenant to an environment. In this sample, we are configuring only one tenant which represents the dev environment.

:ballot_box_with_check: Before we can start the build process, we need to add information about the Azure tenant(s) to the solution. Please change these values in the file [\source\Global\Azure.yml](/source//Global/Azure.yml):

- AzTenantId

### 1.2.2. Starting the Build process

The build process / build pipeline is layed out in multiple tasks that are provided by the [Sampler](https://github.com/gaelcolas/Sampler/), [Sampler.DscPipeline](https://github.com/SynEdgy/Sampler.DscPipeline/) and some custom tasks that are in the folder [.build](/.build). The complexity is wrapped by the script `build.ps1` and this build script is the single trigger we need to know for the beginning.

By starting the build script, this sequence of steps defined in the [build.yaml](/build.yaml) is invoked:

Name | description
--- | ---
Init | Prepare the current PowerShell session for the build.
Clean | Remove previously created artifacts and temporary files form the [output](/output/) folder.
TODO: AzureInit | Details required
LoadDatumConfigData | Load the configuration data from [source](/source/).
TestConfigData | Invoke the tests defined in the folder [tests](/tests/).
CompileDatumRsop | Merge the configuration data into one large hash table.
TestDscResources | Make sure all DSC dependencies are met.
CompileRootConfiguration | Create the MOF file (the instruction file to configure the Azure tenant).
CompileRootMetaMof | Create the Meta MOF files which connect the worker machines to the Azure Automation account.

:ballot_box_with_check: Please open the cloned project in Visual Studio Code and run the build script. The first run will take a few minutes as the required modules must be downloaded first.

:ballot_box_with_check: If the script succeeded, you will find the created artifacts in the [output folder](/output/). You may want to inspect these folders:

- [CompressedModules](/output/CompressedModules/)
- [MOF](/output/MOF/)
- [MetaMOF](/output/MetaMOF//)
- [RSOP](/output/RSOP/)
- [RsopWithSource](/output/RsopWithSource/)

## 1.3. Prepare the LCM Virtual Machine for the first DSC job

The LCM running on this machine runs in the local system context. This context needs to have administrative permissions on the Azure tenant. Previously we have registered the App `DscWorkerDev` which has global admin permissions. We have then assigned the public part of the certificate [DscWorkerDev](/assets/certificates/DscWorkerDev.cer) to this account. In oder to use it, we need to import the certificate including the private key to the VM running the DSC LCM.

### 1.3.1. Importing the `DscWorker` certificate mapped to the `DscWorker` app

:ballot_box_with_check: Copy the file PFX certificate [DscWorkerDev](/assets/certificates/DscWorkerDev.pfx) to `C:\` of the virtual machine `DscLcm`. Then call the following command to import the certificate to the local machine:

```powershell
$password = 'x' | ConvertTo-SecureString -AsPlainText -Force
Import-PfxCertificate -FilePath C:\DscWorkerDev.pfx -Password $password -CertStoreLocation Cert:\LocalMachine\My
```

### 1.3.2. Installing requirements

:ballot_box_with_check: For running the DSC configuration, you need to install the required modules to the virtual machine that runs the LCM. The following scripts does the job.

> :warning: Please change the version of the `Microsoft365DSC` module according to what is defined in [RequiredModules.psd1](/RequiredModules.psd1).

```powershell
Install-Module -Name Microsoft365DSC -RequiredVersion 1.23.315.1 -Force
Install-Module -Name xPSDesiredStateConfiguration -Force

Import-Module -Name Microsoft365DSC -RequiredVersion 1.23.315.1

Update-M365DSCDependencies -Force
```

## 1.4. Pushing the configuration

In this easy lab scenario, we use DSC in push mode to keep things simple. Hence, no Azure Automation Account is required. After everything works, you should move forward and try DSC in pull mode using the Azure Automation State Configuration service.

> :information_source: For more information about the push and pull mode, see [Enacting configurations](https://learn.microsoft.com/en-us/powershell/dsc/pull-server/enactingconfigurations?view=dsc-1.1)

:ballot_box_with_check: Copy the MOF file that you have previously build by calling the [build.ps1](/build.ps1) script to the virtual machine (`C:\DSC`). You find the MOF files in folder [MOF](/output/MOF/).

> :warning: Make sure the MOF file has the same name as the machine or is named `localhost.mof`.

:ballot_box_with_check: Then please push the configuration by calling this command:

```powershell
Start-DscConfiguration -Path C:\DSC -Wait -Force -Verbose
```

:ballot_box_with_check: If no error appeared in the terminal, please check the Azure AD of the tenant that DSC should have configured. There are two test groups defined in the file [LcmDev.yml](/source/AllNodes//Dev/LcmDev.yml). These groups should have been created in your Azure AD.

## 1.5. Next steps

If everything worked, you have successfully applied the configuration layed out in the Yaml files to your tenant(s). You have implemented an Infrastructure as Code model but not yet with a DevOps approach. For DevOps, you want to add continues integration (CI) and continues deployment (CD) in a release pipeline.

The next steps are described in [Release Pipeline](./ReleasePipeline.md).
