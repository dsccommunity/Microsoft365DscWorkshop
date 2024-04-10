# 1. Putting Azure Tenants under Source Control

This project uses Infrastructure as Code (IaC) and DevOps concepts to put Azure Tenants under source control. The configuration of all Azure services is stored in Yaml files which are secured by a Git Repository.

This concept allows multiple tenants to be set up identically or, if necessary, each tenant to be configured with controlled deviation.

## 1.1. Technical Summary

## 1.2. Technologies / Products Used

These are the top project that M365DscWorkshop is based on:

Project Name | Project Description
--- | ---
 [DscWorkshop](https://github.com/dsccommunity/DscWorkshop) | The DscWorkshop is the blueprint for this project where all the threads come together.
[Datum](https://github.com/gaelcolas/Datum) | Datum is used to manage configuration data in a hierarchy adapted to the business context.
[Pester](https://pester.dev/) | Pester is a testing framework to verify the configuration data, the code as well as the outcome after enacting the configuration.
[Sampler](https://github.com/gaelcolas/Sampler) | Enables robust build and release pipelines for most involved open-source projects.
[Microsoft365DSC](https://microsoft365dsc.com/) | This project does the regular work and puts the configuration data and guidelines into practice.

For all other dependencies, please refer to the file [RequiredModules.psd1](/RequiredModules.psd1).

## 1.3. Technical Requirements

This walk through this guide and adapt the project, you need:

- One or more Azure Tenant(s) to manage.
- An Azure DevOps organization hosting this code.
- A virtual machine running on Azure for each tenant you want to manage. This virtual machine read the configuration and applies it to the specified tenant.

## 1.4. Getting started

> :information_source: For an introduction into the principles and patters of the [DscWorkshop](https://github.com/dsccommunity/DscWorkshop), please refer to the [Exercises](https://github.com/dsccommunity/DscWorkshop/tree/main/Exercises). When you have done these exercises, the following steps will make much more sense.

To get started, you just need an Azure tenant and your personal computer. The steps in short are:

1. Fork the project or put it into your own code management solution.
2. Clone your project to your development machine.
3. Set the Azure tenant details in the configuration data.  
4. Build the Artifacts.
5. Run the deployment scripts in the [lab](../lab/) folder.

Please go to the [detailed guide](GettingStarted.md) to get started.
