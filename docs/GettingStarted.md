# 1. Getting started

> Note: If you are only intersted in exporting your Microsoft Azure tenant configuration with [Microsoft365DSC](https://microsoft365dsc.com/) and you do not want to configure your tenants, please refer to [Export your Azure Tenant Configuration](../export/readme.md).

### 1.0.1. :warning: You must be a local administrator one the machine you run the setup scripts on.

## 1.1. Import the Project into Azure DevOps

For this project to work it is required to change the content of some files. Hence, it is required to create yourself a
writable copy of the project. Please import the content of this project into a project hosted on Azure DevOps.

1. Create a new project in your Azure DevOps Organization with the name of your choice.
2. In the new project, click on 'Repos'.
3. As there is no content yet, you are asked to add some code. Please press the 'Import' button.
4. Please use the URL `https://github.com/raandree/Microsoft365DscWorkshop.git` as the 'Clone URL' and click on 'Import' (it may take a view seconds to copy the content).

This guide expects you have created a new project on Azure DevOps and imported the content from here. Alternatively, you can create a fork on GitHub, but then some scripts won't work and you have to make the required tasks manually.

> :warning: You can run the project on any code management / automation platform of your choice, but for the standard setup to work, it is expected
> to host it on Azure DevOps.

## 1.2. Cloning the Project

Clone the project in Visual Studio Code Source Control Activity Bar or use the command `git.exe`. With the following command you clone the Git repository to your local machine. Please change the link according to your Azure DevOps Organization and project name.

> :information_source: By clicking on the clone button in your repository on Azure DevOps you get the HTTPS link to clone from. The git command could look like this:

```powershell
git clone <Link to you Azure DevOps project> <The local path of your choice>
```

## 1.3. Run the Lab Setup Scripts

All the scripts to setup the environment are in the folder [lab](../lab/).

### 1.3.1. `00 Prep.ps1`

> :information_source: This script may kill the PowerShell session when setting local policies required for AutomatedLab. In this case, just restart it.

Call the script [.\lab\00 Prep.ps1](../lab//00%20Prep.ps1). It installs required modules on your machine.

This script set the project name in the [ProjectSettings.yml](../source/Global//ProjectSettings.yml) file to the name of your Azure DevOps project.

It then installs the following modules to your machine:

- [VSTeam](https://github.com/MethodsAndPractices/vsteam)
- [AutomatedLab](https://automatedlab.org/en/latest/) and dependencies

---

## 1.4. Test the Build and Download Dependencies

After having cloned the project to your development machine, please open the solution in Visual Studio Code. In the PowerShell prompt, call the build script:

```powershell
.\build.ps1 -UseModuleFast -ResolveDependency
```

> :information_source: [ModuleFast](https://github.com/JustinGrote/ModuleFast)sometimes has a problem and does not download all the modules it should. If something is missing and you see error messages, please close the PowerShell session and try again. Usually everything works after the second time.

This build process takes around 15 to 20 minutes to complete the first time. Downloading all the required dependencies defined in the file [RequiredModules.psd1](../RequiredModules.psd1) takes time and discovering the many DSC resources in [Microsoft365DSC](https://microsoft365dsc.com/).

After the build finished, please verify the artifacts created by the build pipeline, for example the MOF files in the [MOF](../output/MOF/).

> :information_source: The [MOF](../output/MOF/) folder is not part of the project. It is created by the build process. If your don't find it after having run the build, something went wrong and you probably see errors in the console output of the build process.

---

## 1.5. Set your Azure Tenant Details

This solution can configure as many Azure tenants as you want. You configure the tenants you want to control in the [.\source\Azure.yml](../source//Global/Azure.yml) file. The file contains a usual setup, a dev, test and prod tenant.

- For each environment / tenant, please update the settings `AzTenantId`, `AzTenantName` and `AzSubscriptionId`. The `AzApplicationId`, `AzApplicationSecret` and `CertificateThumbprint` will be handled by the setup scripts you are going to run next.

- Remove the environments you don't want from the [Azure.yml](../source/Global//Azure.yml) file. For this introduction, only the Dev environment is needed.

- Please also remove the build agent yaml-definition including the folders:
  - [Test](../source//BuildAgents/Test/)
  - [Prod](../source//BuildAgents/Prod/)

> :warning: Please don't forget to remove the environments you do not need.
> 
> :information_source: For getting used with the project it is recommended to focus on one tenant only. This reduces the runtime of your tests and the complexity.

The file can look like this for example if you want to configure only one tenant:

```yml
Environments:
  Dev:
    AzTenantId: b246c1af-87ab-41d8-9812-83cd5ff534cb
    AzTenantName: MngEnvMCAP576786.onmicrosoft.com
    AzSubscriptionId: 9522bd96-d34f-4910-9667-0517ab5dc595
    Identities:
    - Name: M365DscSetupApplication
      ApplicationId: <AutoGeneratedLater>
      ApplicationSecret: <AutoGeneratedLater>
    - Name: M365DscLcmApplication
      ApplicationId: <AutoGeneratedLater>
      CertificateThumbprint: <AutoGeneratedLater>
    - Name: M365DscExportApplication
      ApplicationId: <AutoGeneratedLater>
      CertificateThumbprint: <AutoGeneratedLater>
```

---

### 1.5.1. Initialize the session (Init task)

> :warning: Please start a new PowerShell session and do not use the old one. This is because there is a kind of Azure PowerShell module hell (Déjà vu of [Dll Hell](https://en.wikipedia.org/wiki/DLL_hell)) and usually at this point in the process a module is loaded that prevents a newer version from being loaded.
>
> And don't forget: Sometimes just retrying a failed task is the best and easiest solution.

After the preparation script finished, we have all modules and dependencies on the machine to get going. Please run the build script again, but this time just only for initializing the shell:

```powershell
.\build.ps1 -Tasks init
```

---

### 1.5.2. `10 Setup App Registrations.ps1`

The script `10 Setup App Registrations.ps1` creates all the applications in each Azure tenant defined in the [Azure.yml](../source/Global/Azure.yml) file. Then it assigns these apps very high privileges as they are used to control and export the tenant. The app `M365DscLcmApplication` will be used by the Azure DevOps build agent(s) to put your tenant into the desired state. For each app, a service principal is created in Exchange Online.

> :information_source: To clean up the tenant if you don't want to continue the project, use the script [98 Cleanup App Registrations.ps1](../lab//98%20Cleanup%20App%20Registrations.ps1).

The App ID and the plain-text secrets are shown on the console in case you want to copy them. They are also written encrypted to the [Azure.yml](../source/Global/Azure.yml) file. The file is then committed and pushed to the code repository.

> :warning: The password for encrypting the app secret is taken from the [Datum.yml](../source//Datum.yml) file. This is not a secure solution and only meant to be used in a proof of concept. For any production related tenant, the pass phrase should be replaced by a certificate.

---

### 1.5.3. 1.5.3 `11 Test Connection.ps1`

In the last task we have created some applications and stored the credentials for authentication to the [Azure.yml](../source/Global/Azure.yml) file. Now it is time to test if the authentication with the new applications work.

Please call the script [11 Test Connection.ps1](../lab/11%20Test%20Connection.ps1). The last line of the output should be `Connection test completed`.

--- 

### 1.5.4. `20 Setup AzDo Project.ps1`

This script prepares the Azure DevOps project. The parameters are in the file [ProjectSettings.yml](../source//Global/ProjectSettings.yml).

```yml
OrganizationName: <OrganizationName>
PersonalAccessToken: <PersonalAccessToken>
ProjectName: Microsoft365DscWorkshop
AgentPoolName: DSC
```

If you are ok with the name of the new agent pool, you don't have to change anything here. The script [20 Setup AzDo Project.ps1](../lab/20%20Setup%20AzDo%20Project.ps1) will ask for the required information and update the file [ProjectSettings.yml](../source//Global/ProjectSettings.yml) for you.

1. Please create an Personal Access Token (PAT) for your Azure DevOps organization with the required access level to manage the project. Copy the PAT to the clipboard.

2. Then call the script [20 Setup AzDo Project.ps1](../lab/20%20Setup%20AzDo%20Project.ps1) and provide the required information the script asks for.

```powershell
& '.\20 Setup AzDo Project.ps1'
```

The script will:

- Ask for Azure DevOps organization name.
- Ask for the Azure DevOps project name.
- Ask for the Azure DevOps personal access token.
- Update the file [ProjectSettings.yml](../source/Global/ProjectSettings.yml) according to the data you provided.
- Creates an agent pool named `DSC`.
- Disables non-required features in the project.
- Creates build environments as defined in [Azure.yml](../source/Global/Azure.yml) file.
- Creates the pipelines for full build, apply and test.

Please inspect the project. You should see the new environment(s) as well as the new agent pool and the pipelines now.

---

### Create and Sync the Azure LabSources Share

> :information_source: If you have never used AutomatedLab in your tenant, the AutomatedLab LabSources share is missing in your Azure subscription. If you have used it successfully before, you can skip this task.

AutomatedLab uses a predefined folder structure as a script and software repository.

Please run [New-LabSourcesFolder](https://automatedlab.org/en/latest/AutomatedLabCore/en-us/New-LabSourcesFolder/) to download the LabSources content to your machine.

```powershell
New-LabSourcesFolder -DriveLetter <DriveLetter>
```

As machines in Azure cannot access this share, it needs to be synchronized into an Azure storage account. This can be done with the command [Sync-LabAzureLabSources](https://automatedlab.org/en/latest/AutomatedLabCore/en-us/Sync-LabAzureLabSources/).

---

### 1.5.5. `30 Create Agent VMs.ps1`

The script [30 Create Agent VMs.ps1](../lab//20%20Create%20Agent%20VMs.ps1) creates one VM in each tenant. It then assigns a Managed Identity to each VM and gives that managed identity the required permissions to control the Azure tenant with Microsoft365DSC.

Later we connect that VM to Azure DevOps as a build agent. It will be used later to build the DSC configuration and push it to the respective Azure tenant.

For creating the VMs, we use [AutomatedLab](https://automatedlab.org/en/latest/). All the complexity of that task is handled by that AutomatedLab. The script should run 20 to 30 minutes.

> :warning: Before running the script [30 Create Agent VMs.ps1](../lab/20%20Create%20Agent%20VMs.ps1), please set a password for the build workers in the file [AzureDevOps.yml](../source/Global/AzureDevOps.yml) by replacing the placeholder `<Password>` with your desired password. If you forget this or your chosen password does not have the necessary complexity, you will get an error later.

```yml
BuildAgents:
  UserName: worker
  Password: Somepass1
```

Running the script [30 Create Agent VMs.ps1](../lab/20%20Create%20Agent%20VMs.ps1) takes about half an hour, depending on how many tenants you have configured. Time to grab a coffee.

---

### 1.5.6. `31 Agent Setup.ps1`

The script [31 Agent Setup.ps1](../lab//31%20Agent%20Setup.ps1) connects to each build worker VM created in the previous step. It installs

- PowerShell 7
- Git
- VSCode. After that it installs
- Azure DevOps Build Agent
- Latest PowerShellGet and NuGet package provider
- Then the Azure Build Agent is connected to the specified Azure DevOps Organization and is added to the `DSC` agent pool.
- A self-signed client authentication certificate is created on the build agent. The certificate's thumbprint is written to the [Azure.yml](../source/Global/Azure.yml) file.

Please check the DSC Azure DevOps Agent Pool to see if the new worker appears there. Please also check its capabilities. There should be a capability named `BuildEnvironment` with the value of the respective environment.

---

## 1.6. Running the Pipeline

The script [20 Configure AzDo Project.ps1](../lab//30%20Setup%20AzDo%20Project.ps1) has created these pipelines:

- M365DSC push

Only this pipeline has triggers for continuous integration and is executed to run every time something is committed to the main branch. The pipeline creates the artifacts, applies them to the configured tenants and tests whether the configuration has been applied successfully.

If you want to trigger these steps in individually, you can start one of these pipelines manually:
- M365DSC test
- M365DSC apply
- M365DSC build
