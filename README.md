# M365DscWorkshop - Controlling your Entra ID and Microsoft 365 with DSC

## Where do we come from?

### The [DscWorkshop](https://github.com/dsccommunity/DscWorkshop)

The [DscWorkshop](https://github.com/dsccommunity/DscWorkshop) blueprint was started in 2017. The main purpose of the project was and still is to gather all best practices the DSC community gathered and developed over the last years. The [DscWorkshop](https://github.com/dsccommunity/DscWorkshop) is primarily for managing a on-prem or cloud-hosted server infrastructure.

To understand the concept and tools used here, please also refer to the [DscWorkshop](https://github.com/dsccommunity/DscWorkshop) and especially to the [exercises](https://github.com/dsccommunity/DscWorkshop/tree/main/) there which were designed to give you a quick but comprehensive introduction.

### [Microsoft365DSC - Your Cloud Configuration](https://microsoft365dsc.com/)

[Microsoft365DSC - Your Cloud Configuration](https://microsoft365dsc.com/) provides almost 300 DSC Resources to manage Azure AD, Exchange Online, SharePoint Online, Teams, and many more services. This project combines the power of  [Microsoft365DSC - Your Cloud Configuration](https://microsoft365dsc.com/) and the [DscWorkshop](https://github.com/dsccommunity/DscWorkshop).

### What you get

Like the [DscWorkshop](https://github.com/dsccommunity/DscWorkshop) offers a robust, scalable and comfortable tooling for managing a server infrastructure with DSC, so does the M365DscWorkshop for putting Azure tenants under source control.

The concept supports managing one or multiple Azure tenants. The configuration data for the tenants is managed in a [Datum](https://github.com/gaelcolas/Datum) Yaml file hierarchy. This solution is the idea way to keep a tenants for Dev, Test and Production in sync. The hierarchical configuration data allows defining a baseline intended for all tenants. This baseline can be customized on a higher level in the hierarchy, for example to relax security settings in the Dev tenant.

Most automation systems are supported, Azure DevOps is the preferred one for easy integration with Azure security. Supports self-hosted build agents with a user-assigned Managed Identity or Microsoft-hosted agents with certificate authentication.

![Overview](docs/Overview-Push%20Mode.drawio.svg)

### Getting Started

For getting started, please refer to the [technical guide](./docs/readme.md).
