# Preparing your machine and retrieving your credentials

- [Preparing your machine and retrieving your credentials](#preparing-your-machine-and-retrieving-your-credentials)
  - [1. Requirements](#1-requirements)
  - [2. Preparing the machine](#2-preparing-the-machine)
    - [2.1. Required Software](#21-required-software)
    - [2.2. Account Information File](#22-account-information-file)

## 1. Requirements

- For this lab you need a Windows machine, your notebook or a virtual machine, with **admin permissions** and the following software.
- A piece of paper with your user account in Azure and the decryption key.

## 2. Preparing the machine

### 2.1. Required Software

- [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)
- [Git](https://git-scm.com/downloads)
- [Visual Studio Code](https://code.visualstudio.com/download) - Install also the install the PowerShell extension in VSCode.

In the powershell terminal, install the modules `powershell-yaml`, `ProtectedData` and `Datum.ProtectedData`:

```powershell
Install-Module -Name powershell-yaml, ProtectedData, Datum.ProtectedData -Force
```

### 2.2. Account Information File

- Create the folder `C:\M365Dsc`. Of course you can choose another location as well.
- Download the file mentioned on your paper from <https://github.com/dsccommunity/Microsoft365DscWorkshop/tree/main/Summit2025/LabAccounts> and put it in that folder.
- Then open the folder in VSCode.

> [!WARNING] Please always start VSCode as admin for this and the upcoming tasks.

You should see the yaml file in the VSCode explorer. Please click on it to see the content. Note that the credentials are encrypted. On your paper, you find the password to decrypt the credentials. Let's suppose your file is named `SummitTestUser1.yaml` and the password on your paper is `zjrsxgwb`. To get the password for the user account and the application registration, run the following commands in the PowerShell Terminal:

```powershell
$data = Get-Content .\SummitTestUser1.yaml | ConvertFrom-Yaml
$data #to have a look at the data

$pass = 'zjrsxgwb' | ConvertTo-SecureString -AsPlainText -Force

$data.EncSecret | Unprotect-Datum -Password $pass
$data.UserPassword | Unprotect-Datum -Password $pass
```

> :warning: Please note down both, the user password and the plain text secret for later use in notepad or VSCode.

---

The next task [Graph API Cmdlets](./20%20Graph%20API%20Cmdlets.md) familiarizes you with the Graph Cmdlets and authentication with the Graph API.
