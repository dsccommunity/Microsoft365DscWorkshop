# The Microsoft365DscWorkshop Blueprint

- [The Microsoft365DscWorkshop Blueprint](#the-microsoft365dscworkshop-blueprint)
  - [1. That is the Microsoft365DscWorkshop Blueprint?](#1-that-is-the-microsoft365dscworkshop-blueprint)
    - [1.1. Relationship to DscWorkshop](#11-relationship-to-dscworkshop)
    - [1.2. Key Benefits](#12-key-benefits)
  - [2. How to get started](#2-how-to-get-started)
  - [3. Seeing the Microsoft365DscWorkshop in action](#3-seeing-the-microsoft365dscworkshop-in-action)
    - [3.1. Cloning the Project](#31-cloning-the-project)
    - [3.2. Testing the Local Build](#32-testing-the-local-build)
    - [3.3. Add a New Group to the Configuration Database](#33-add-a-new-group-to-the-configuration-database)
    - [3.4. Create a Pull Request to Inform your Workmates](#34-create-a-pull-request-to-inform-your-workmates)
    - [3.5. Conclusion](#35-conclusion)
    - [3.6. Extra task: What's next? Configuration Data and the Datum module](#36-extra-task-whats-next-configuration-data-and-the-datum-module)

## 1. That is the Microsoft365DscWorkshop Blueprint?

**Microsoft365DscWorkshop** is a **blueprint** for implementing and managing Microsoft 365 configurations using the **Microsoft365Dsc** PowerShell module. It provides a structured framework, best practices, and reusable examples for automating Microsoft 365 services (e.g., Teams, Exchange Online, SharePoint, Azure AD) through **Desired State Configuration (DSC)**. Similarly, the **DscWorkshop** serves as a foundational blueprint for on-premises DSC projects, guiding infrastructure-as-code (IaC) practices for traditional systems like Windows Server, Hyper-V, and file services.

### 1.1. Relationship to DscWorkshop

- **Specialized Extension**: Microsoft365DscWorkshop adapts the core principles of the DscWorkshop (declarative configuration, idempotency, drift remediation) to Microsoft 365 cloud services.
- **Shared Philosophy**: Both emphasize modularity, repeatability, and compliance, but **Microsoft365DscWorkshop** focuses on cloud-native management using the Microsoft365Dsc module, while **DscWorkshop** targets on-premises infrastructure with native DSC resources.

### 1.2. Key Benefits

1. **Implementation Blueprint**: Accelerates deployment by providing pre-built templates, architectural guidance, and workflow examples tailored to Microsoft 365 environments.  
2. **Standardization**: Ensures consistent configurations across tenants, reducing drift and enforcing governance policies (e.g., security baselines, licensing, user provisioning).  
3. **Best Practices**: Integrates lessons learned from real-world deployments, such as credential management, error handling, and incremental configuration rollouts.  
4. **Scalability**: Demonstrates patterns for managing large-scale Microsoft 365 ecosystems, including multi-tenant and hybrid scenarios.  
5. **DevOps Integration**: Guides automation pipelines (CI/CD) for testing, validating, and deploying configurations alongside tools like Azure DevOps or GitHub Actions.  
6. **Community-Driven**: Builds on the open-source Microsoft365Dsc module, offering extensibility and collaboration opportunities.  
7. **Cross-Service Coordination**: Unifies management of disparate Microsoft 365 workloads (e.g., Intune, Purview, Power Platform) under a single DSC framework.  

---

By serving as blueprints, both projects reduce the learning curve and setup time for teams adopting DSC, whether for on-premises infrastructure (**DscWorkshop**) or cloud-first Microsoft 365 environments (**Microsoft365DscWorkshop**). They enable organizations to enforce compliance, automate at scale, and maintain operational consistency.

## 2. How to get started

If you are interested of testing out the [Microsoft365DscWorkshop](https://github.com/dsccommunity/Microsoft365DscWorkshop) approach, please have a look at the [Getting started guide](https://github.com/dsccommunity/Microsoft365DscWorkshop/tree/main/docs). The whole process is fully automated and should not take more than an hour to put a tenant under source control.

## 3. Seeing the Microsoft365DscWorkshop in action

### 3.1. Cloning the Project

Let's say, someone in our company has already done the setup mentioned in the previous paragraph. Now we want to do a change to the tenant which is under source control.

First, we need to logon to go with a browser to the lab repository [M365RA1](https://dev.azure.com/randre/M365RA1/_git/M365RA1). You will be asked to authenticate yourself. Please use the username (like <SummitTestUser2@MngEnvMCAP167509.onmicrosoft.com>) and the previously decrypted user password. :warning: Without this step, your user account is not initialized in Azure DevOps and you will not be able to do the next step.

Then we have to clone the project so we can make changes its content. Please open VSCode and clone the project from the this link: <https://dev.azure.com/randre/M365RA1/_git/M365RA1>. When you are asked for credentials, use the same ones as you did in the previous step.

> [!caution] Please open VSCode as admin as we are interacting with the `Program Files` folder.

### 3.2. Testing the Local Build

The Microsoft365DscWorkshop has a lot of dependencies that you luckily do not have to resolve yourself. The dependencies are defined in the file [/RequiredModules.psd1](/RequiredModules.psd1) and will be stores in [/output/RequiredModules](/output/RequiredModules). Please run the following command to download all the dependencies and get ready for the first build.

```powershell
.\build.ps1 -ResolveDependency -UseModuleFast -Tasks noop
```

> :information_source: The parameter `UseModuleFast` makes use of [ModuleFast](https://github.com/JustinGrote/ModuleFast) which is by far the fastest way to download PowerShell modules. `-Tasks noop` (No Operation) means to do nothing except resolving the dependencies.

Now check out the [/output/RequiredModules](/output/RequiredModules) folder.

To prevent conflicts with previously installed modules, please run the `CleanModuleFolder` task.

```powershell
.\build.ps1 -Tasks CleanModuleFolder
```

Now, please run a full build

```powershell
.\build.ps1
```

The full build will generate all artifacts required for a DSC scenario:

- The [RSOP](/output//RSOP/) and [RsopWithSource](/output//RsopWithSource/)folder - RSOP provides **visibility and confidence** in your configuration management by ensuring hierarchical data is resolved correctly, minimizing deployment surprises.
- The [MOF](/output//MOF/) folder contains the MOF files.

The other artifacts are not important for this scenario.

### 3.3. Add a New Group to the Configuration Database

Now let's do a change by

- creating a new branch in the Git repository.
- adding a new group to the yaml configuration database.
- test the local build after we have done the change.
- inspect the RSOP.
- publish the branch to Azure DevOps.
- create a pull request to notify our colleagues about the change and trigger the review process.

Before being able to commit something to the Git repository, you need to set your user configuration to let Git know who you are. Please use the email address and user name from the account info yaml file.

```powershell
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

Then we create a new branch:

```powershell
git checkout -b <Choose a name>
```

> :information_source: The branch name is shown in VSCode in the lower left corner. You should see the name you have chosen there. If it still says that you are on the main branch, something went wrong.

Open the file [/source/1-AllTenantsConfig/AzureAd/cAADGroup.yml](/source/1-AllTenantsConfig/AzureAd/cAADGroup.yml). It contains a list of groups. PLease add another one by just copy and paste an already existing group definition. Please change the `MailNickname`, `DisplayName` and the `Description` to something that is hopefully unique.

> :warning: The indentation in yaml is very important. Usually VSCode will highlight syntax errors.

Save the file and commit it to the local git repository:

```powershell
git add .
git commit -m <give your commit a comment>
```

The change is only within your local git repository, not yet in Azure DevOps. Same is with the new branch. Before we publish the branch, we want to see if the project still builds. Please run the build script again and afterwards please check if your new group is in the RSOP file.

```powershell
.\build.ps1
```

If the build succeeded and your are happy with the RSOP, please publish the new branch by running

```powershell
git push --set-upstream origin g1
```

Good, all done.

### 3.4. Create a Pull Request to Inform your Workmates

What is the purpose of a pull request (PR)? **Propose**, **review**, and *merge** code changes **safely**.

- **Collaborate**: Discuss changes before merging.  
- **Ensure Quality**: Review code for errors/standards.  
- **Integrate**: Merge approved updates into the main codebase.  

To create the pull request, navigate to the Azure DevOps repository: <https://dev.azure.com/randre/M365RA1/_git/M365RA1>. You should still be authenticated from the last visit. If not, please use the username (like <SummitTestUser2@MngEnvMCAP167509.onmicrosoft.com>) and the previously decrypted user password.

On the left side there is a menu group called `Repos` and underneath `Pull requests`. Please go there. Azure DevOps knows about your last change and the new branch and should suggest you to create a PR by clicking on the `Create a pull request` button on the right side.

You can give your PR a title and description and then click on `Create`.

What happens next?

- The reviewers of the project are notified as defined in the branch policies.
- A build is triggered to check whether the project can still be built and whether all defined tests are successful, as you may not have tested this yourself.

Let's hope that your PR is approved...

### 3.5. Conclusion

**Conclusion**  
In this lab, we explored the **Microsoft365DscWorkshop**, a framework for automating and managing Microsoft 365 configurations using Infrastructure as Code (IaC) principles. By leveraging PowerShell Desired State Configuration (DSC), participants learned to enforce standardized, compliant settings across cloud services like Azure AD, Teams, and SharePoint. Key takeaways include:  

- **Automation at Scale**: Streamlining Microsoft 365 management through declarative configurations, reducing manual errors and configuration drift.  
- **DevOps Integration**: Implementing CI/CD pipelines for testing, validation, and collaboration via pull requests, ensuring safe and auditable deployments.  
- **Operational Consistency**: Using modular templates and version control to maintain uniformity across environments, even in hybrid or multi-tenant setups.  

This approach is vital for organizations adopting cloud-first strategies, as it enables rapid, repeatable, and governed management of complex Microsoft 365 ecosystems while aligning with modern DevOps practices. By mastering these tools, teams can achieve agility, compliance, and resilience in dynamic cloud environments.

---

### 3.6. Extra task: What's next? Configuration Data and the Datum module

If you are interested in some of the hidden mechanics, you may want to go on with the extra task [](./51%20Configuration%20Data.md)
