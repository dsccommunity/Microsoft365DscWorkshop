### 1.3.2. Create and Sync the Azure LabSources Share

> :information_source: If you have never used AutomatedLab in your tenant, the AutomatedLab LabSources share is missing in your Azure subscription. If you have used it successfully before, you can skip this task.

AutomatedLab uses a predefined folder structure as a script and software repository.

1. Please run [New-LabSourcesFolder](https://automatedlab.org/en/latest/AutomatedLabCore/en-us/New-LabSourcesFolder/) to download the LabSources content to your machine.

```powershell
New-LabSourcesFolder -DriveLetter <DriveLetter>
```

2. As machines in Azure cannot access this share, it needs to be synchronized into an Azure storage account. This can be done with the command [Sync-LabAzureLabSources](https://automatedlab.org/en/latest/AutomatedLabCore/en-us/Sync-LabAzureLabSources/).

---
