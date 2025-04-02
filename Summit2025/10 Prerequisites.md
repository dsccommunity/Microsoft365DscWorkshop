# Titel

## Requirements

- for this lab you need a Windows machine, your notebook or a virtual machine, with admin permissions and the following software
- a piece of paper with your user account in Azure

## Preparing the machine

### Required Software

<https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5>

<https://git-scm.com/downloads>

<https://code.visualstudio.com/download>

install the powershell extension in VSCode

in the powershell terminal, install the modules powershell-yaml, ProtectedData and Datum.ProtectedData:

```powershell
Install-Module -Name powershell-yaml, ProtectedData, Datum.ProtectedData -Force
```

### Account Information File

- create the folder C:\M365Dsc. Of course you can choose another location as well.-
- download the file mentioned on your paper from <https://github.com/raandree/Microsoft365DscWorkshop/tree/main/Summit2025/LabAccounts> and put it in that folder.
- Then open the folder in VSCode.

You should see the yaml file in the VSCode explorer. If you click on it to see the content. Note that the credentials are encrypted. On your paper, you fine the password to decrypt the credentials. Let's suppose your file is named `SummitTestUser1.yaml` and the password is `zjrsxgwb`. To get the password for the user account and the application registration, run the following commands in the PowerShell Terminal:

```powershell
$data = Get-Content .\SummitTestUser1.yaml | ConvertFrom-Yaml
$data #to have a look at the data

$pass = 'zjrsxgwb' | ConvertTo-SecureString -AsPlainText -Force
$data.EncSecret | Unprotect-Datum -Password $pass
$data.UserPassword | Unprotect-Datum -Password $pass
```

> :warning: Please note down both, the user password and the plain text secret for later use in notepad or VSCode.
