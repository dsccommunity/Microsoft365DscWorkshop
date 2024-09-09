# Export your Azure Tenant Configuration to Yaml or Json

Regularly exporting your Azure tenant configuration using Microsoft365DSC can be highly beneficial for several reasons:

1. Disaster Recovery: While Microsoft365DSC is not a full disaster recovery solution, having your configuration in code can significantly aid in recovering from outages or disasters. It supports your existing disaster recovery strategy by ensuring that configurations can be quickly restored1.

1. Configuration Management: Microsoft365DSC helps you manage and automate the deployment and update of Microsoft 365 settings across multiple tenants, environments, and regions. This ensures consistency and reduces the risk of configuration drift2.

1. Change Tracking: By exporting configurations regularly, you can track changes made by service administrators. This adds an approval process to deployments and helps prevent untracked changes to your Microsoft 365 tenants3.

1. Security and Compliance: Regular exports can help you maintain compliance with internal policies and external regulations. It allows you to review and audit configurations to ensure they meet security standards2.

1. Collaboration and Documentation: Exporting configurations can facilitate collaboration between different teams, such as IT, security, and compliance. It also serves as documentation for your tenant's configuration, making it easier to understand and manage2.

If doing the export on a regular basis, more tooling around the export process is required. The tooling should make the export more comfortable, customizable and be able to run within a PowerShell session as well as a build agent, for example an Azure Devops build agent.

The following steps guide you through the process of customizing and running the export based on the framework provided by [Sampler](https://github.com/gaelcolas/Sampler) and the [Microsoft365DscWorkshop](https://github.com/raandree/Microsoft365DscWorkshop).



[Azure.yml](../source//Global//Azure.yml)
