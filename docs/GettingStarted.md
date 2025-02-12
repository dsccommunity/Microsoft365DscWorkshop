# The quick guide to the Microsoft365DscWorkshop

- [The quick guide to the Microsoft365DscWorkshop](#the-quick-guide-to-the-microsoft365dscworkshop)
  - [1. Getting started](#1-getting-started)
    - [1.0.1. :warning: You must be a local administrator one the machine you run the setup scripts on](#101-warning-you-must-be-a-local-administrator-one-the-machine-you-run-the-setup-scripts-on)
  - [1.1. Import the Project into Azure DevOps](#11-import-the-project-into-azure-devops)
  - [1.2. Cloning the Project](#12-cloning-the-project)
  - [1.3. Run the Lab Setup Scripts](#13-run-the-lab-setup-scripts)
    - [1.3.1. `00 Prep.ps1`](#131-00-prepps1)
    - [1.3.2. Test the Build and Download Dependencies](#132-test-the-build-and-download-dependencies)
  - [1.4. Set your Azure Tenant Details](#14-set-your-azure-tenant-details)
    - [1.4.1. Initialize the session (Init task)](#141-initialize-the-session-init-task)
    - [1.4.2. `10 Setup App Registrations.ps1`](#142-10-setup-app-registrationsps1)
    - [1.4.3. 1.5.3 `11 Test Connection.ps1`](#143-153-11-test-connectionps1)
    - [1.4.4. `20 Setup AzDo Project.ps1`](#144-20-setup-azdo-projectps1)
    - [1.4.5. `30 Create Agent VMs.ps1`](#145-30-create-agent-vmsps1)
    - [1.4.6. `31 Agent Setup.ps1`](#146-31-agent-setupps1)
  - [1.5. Running the Pipeline](#15-running-the-pipeline)
- [The quick guide to the Microsoft365DscWorkshop](#the-quick-guide-to-the-microsoft365dscworkshop-1)

## 1. Getting started

> Note: If you are only intersted in exporting your Microsoft Azure tenant configuration with [Microsoft365DSC](https://microsoft365dsc.com/) and you do not want to configure your tenants, please refer to [Export your Azure Tenant Configuration](../export/readme.md).

### 1.0.1. :warning: You must be a local administrator one the machine you run the setup scripts on

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

After having cloned the project to your development machine, please open the solution in Visual Studio Code.

### 1.3.1. `00 Prep.ps1`

In the PowerShell prompt, please call the script [.\lab\00 Prep.ps1](../lab//00%20Prep.ps1). All script except the build script are in the folder [lab](../lab/), so you have to jump between the lab folder and the project root folder from time to time.

> :information_source: This script may kill the PowerShell session when setting local policies required for AutomatedLab. In this case, just try again.

Call the script [.\lab\00 Prep.ps1](../lab//00%20Prep.ps1). It does the following steps:

- It then installs the following modules to your machine:
  - [VSTeam](https://github.com/MethodsAndPractices/vsteam)
  - [AutomatedLab](https://automatedlab.org/en/latest/) and dependencies
- This script set the project name in the [ProjectSettings.yml](../source/Global//ProjectSettings.yml) file to the name of your Azure DevOps project. You should see the change to the file in the source control panel. It will be committed later to the Git repository.

---

### 1.3.2. Test the Build and Download Dependencies

After having cloned the project to your development machine, please open the solution in Visual Studio Code. In the PowerShell prompt, call the build script:

```powershell
.\build.ps1 -UseModuleFast -ResolveDependency
```

> :information_source: [ModuleFast](https://github.com/JustinGrote/ModuleFast)sometimes has a problem and does not download all the modules it should. If something is missing and you see error messages, please close the PowerShell session and try again. Usually everything works after the second time.

This build process takes around 15 to 20 minutes to complete the first time. Downloading all the required dependencies defined in the file [RequiredModules.psd1](../RequiredModules.psd1) takes time and discovering the many DSC resources in [Microsoft365DSC](https://microsoft365dsc.com/).

After the build finished, please verify the artifacts created by the build pipeline, for example the MOF files in the [MOF](../output/MOF/) folder.

> :information_source: The [MOF](../output/MOF/) folder is not part of the project. It is created by the build process. If you don't find it after having run the build, something went wrong and you probably see errors in the console output of the build process.

---

## 1.4. Set your Azure Tenant Details

This solution can configure as many Azure tenants as you want. You configure the tenants you want to control in the [.\source\Azure.yml](../source//Global/Azure.yml) file. The file contains a usual environment setup, a dev, test and prod tenant.

- For each environment / tenant, please update the settings `AzTenantId`, `AzTenantName` and `AzSubscriptionId`. The `AzApplicationId`, `AzApplicationSecret` and `CertificateThumbprint` will be handled by the setup scripts you are going to run next.

- Remove the environments you don't want from the [Azure.yml](../source/Global//Azure.yml) file. For this introduction, only the Dev environment is needed.

- Please also remove the build agent yaml-definition including the folders that are not required for this introduction:
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

### 1.4.1. Initialize the session (Init task)

> :warning: Please start a new PowerShell session and do not use the old one. This is because there is a kind of Azure PowerShell module hell (Déjà vu of [Dll Hell](https://en.wikipedia.org/wiki/DLL_hell)) and usually at this point in the process a module is loaded that prevents a newer version from being loaded.
>
> And don't forget: Sometimes just retrying a failed task is the best and easiest solution.

After the preparation script [.\lab\00 Prep.ps1](../lab//00%20Prep.ps1) and the [build.ps1](../build.ps1) finished, we have all modules and dependencies on the machine to get going. Please run the build script again, but this time just only for initializing the new shell:

```powershell
.\build.ps1 -Tasks init
```

---

### 1.4.2. `10 Setup App Registrations.ps1`

Please run the script [10 Setup App Registrations.ps1](../lab/10%20Setup%20App%20Registrations.ps1). It creates all the required applications in each Azure tenant defined in the [Azure.yml](../source/Global/Azure.yml) file. Then it assigns these apps very high privileges as they are used to control and export the tenant later.

- The app `M365DscSetupApplication` is used to do the initial setup of the environment. In theory it is also possible to do this with a Entra ID user but usually authentication requirements interfere or stop the automation process.
- The app `M365DscLcmApplication` will be used by the Azure DevOps build agent(s) to put your tenant into the desired state. For each app, a service principal is created in Exchange Online as well.
- The `M365DscExportApplication` application will be only used by the export pipeline. Exporting will be explained in #TODO.

> :information_source: To clean up the tenant if you don't want to continue the project, use the script [98 Cleanup App Registrations.ps1](../lab//98%20Cleanup%20App%20Registrations.ps1).

The App ID and the plain-text secrets are shown on the console in case you want to copy them. They are also written to the [Azure.yml](../source/Global/Azure.yml) file but  encrypted. The file is then committed and pushed to the code repository.

> :warning: The password for encrypting the app secrets is taken from the [Datum.yml](../source//Datum.yml) file. This is not a secure solution and only meant to be used in a proof of concept. For any production related tenant, the pass phrase should be replaced by a certificate.

After the script has created the applications and added the information to the [Azure.yml](../source/Global/Azure.yml) file, it will commit and push the changes to the Git repository.

---

### 1.4.3. 1.5.3 `11 Test Connection.ps1`

In the last task we have created some applications and stored the credentials for authentication to the [Azure.yml](../source/Global/Azure.yml) file. Now it is time to test if the authentication with the new applications work.

Please call the script [11 Test Connection.ps1](../lab/11%20Test%20Connection.ps1). The last line of the output should be `Connection test completed`.

---

### 1.4.4. `20 Setup AzDo Project.ps1`

This script prepares the Azure DevOps project and stores the information in the [ProjectSettings.yml](../source//Global/ProjectSettings.yml) file. The script will sak for data if there are placeholders in the config file.

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

### 1.4.5. `30 Create Agent VMs.ps1`

The script [30 Create Agent VMs.ps1](../lab//20%20Create%20Agent%20VMs.ps1) creates one VM in each tenant. It then assigns a Managed Identity to each VM and gives that managed identity the required permissions to control the Azure tenant with Microsoft365DSC.

Later we connect that VM to Azure DevOps as a build agent. It will be used later to build the DSC configuration and push it to the respective Azure tenant.

For creating the VMs, we use [AutomatedLab](https://automatedlab.org/en/latest/). All the complexity of that task is handled by that AutomatedLab. The script should run 20 to 30 minutes.

```yml
BuildAgents:
  UserName: worker
  Password: Somepass1
```

Please run the script [30 Create Agent VMs.ps1](../lab/20%20Create%20Agent%20VMs.ps1). You will be prompted to chose a password for the build worker VMs. Time to grab a coffee...

> :warning: Please make sure the password meets the Windows standard complexity.

---

### 1.4.6. `31 Agent Setup.ps1`

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

## 1.5. Running the Pipeline

The script [20 Configure AzDo Project.ps1](../lab//30%20Setup%20AzDo%20Project.ps1) has created these pipelines:

- M365DSC push
- M365DSC test
- M365DSC apply
- M365DSC build

Only the pipeline `M365DSC push` has triggers for continuous integration and is executed every time something is committed to the main branch. The pipeline creates the artifacts required for DSC, applies them to the configured tenants and tests whether the configuration has been applied successfully.

The pipeline `M365DSC push` should have been triggered by now but cannot continue as some permissions are missing.

- Go to the pipelines panel in your Azure DevOps project.
- You should now see the details of the pipeline run that was automatically triggered. You should see the message 'This pipeline needs permission to access a resource before this run can continue to Build of environment Dev'.

Click the `View` button next to the message `This pipeline needs permission to access a resource before this run can continue to Build of environment Dev` and then the button `Permit` in the `Waiting for review` dialog.

After some more seconds, your build worker will take the job and start the work.

> If you want to see in more detail what the build agent is doing, click on the stage `Build of environment Dev`. In [1.3.2. Test the Build and Download Dependencies](###1.3.2.TesttheBuildandDownloadDependencies) you started the build script on your machine. It created some artifacts like the RSOP and MOF files. Now the same process in running on the build server, hence the output should look like familiar.

After the first stage (`Build of environment Dev`) is finished, please go to the next stage named `Deployment in Dev`. As this is the first time the pipeline runs, the pipeline needs to be granted permission to deploy to the Dev environment.

Please click on the `View` button next to the message `This pipeline needs permission to access a resource before this run can continue to Start DSC Configuration of environment Dev` and then on `Permit` like you did in the stage before.

The stage `Deployment in Dev` does the actual job: It compares the current state of your Azure tenant with the desired state defined in the yaml files.For each setting that is not in the desired state, Microsoft365DSC will try to move it into the desired state.

The last stage is `Validating DSC Configuration`. We expect the current state of the Azure tenant(s) to be as defined in the Yaml database as the `Deployment in Dev` just finished its job. To make sure that this is really the case, this pipeline stage compares the current to the desired state once again and reports any differences between them. If this stage does not fail, we know that everything is we expect it to be.

# The quick guide to the Microsoft365DscWorkshop

You have completed the getting started guide. You now have an Azure tenant under source control. To follow DevOps best practices, all changes to your Azure tenant should be made through the pipelines you have set up. This ensures that all changes are tracked, repeatable, and can be rolled back if necessary.

From now on, you should:

1. **Make Changes in Source Control**: Any configuration changes should be made in the YAML files within your repository. This ensures that all changes are versioned and can be reviewed through pull requests.
2. **Run Pipelines for Deployment**: Use the Azure DevOps pipelines to apply changes to your Azure tenant. This ensures that the desired state defined in your YAML files is enforced.
3. **Monitor and Validate**: Regularly monitor the pipeline runs and validate that the deployments are successful. The validation stage in your pipeline will help ensure that the current state matches the desired state.
4. **Iterate and Improve**: Continuously improve your configurations and pipelines. As you become more familiar with Microsoft365DSC and Azure DevOps, you can add more automation and checks to your processes.

By following these practices, you will maintain a consistent and reliable configuration for your Azure tenant, leveraging the power of DevOps and infrastructure as code.
