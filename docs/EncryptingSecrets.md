- [1. Encrypting Secrets in Configuration Data](#1-encrypting-secrets-in-configuration-data)
  - [1.1. Import the module `Helpers.psm1`](#11-import-the-module-helperspsm1)
  - [1.2. Create a Document Encryption Certificate](#12-create-a-document-encryption-certificate)
  - [1.3. Update the `Datum.yml` file](#13-update-the-datumyml-file)
  - [1.4. Update the existing Credentials](#14-update-the-existing-credentials)
  - [1.5. Test your new Encrypted Secrets](#15-test-your-new-encrypted-secrets)
  - [Update Remaining Credentials](#update-remaining-credentials)

# 1. Encrypting Secrets in Configuration Data

In order to create the environment and all required parts, this project must connect to an Azure tenant with an App that was registered when the script [10 Setup App Registrations.ps1](../lab//10%20Setup%20App%20Registrations.ps1) was called. The script writes the App ID and the App's secret to the file [Azure.yml](../source/Global/Azure.yml) file. The secret is encrypted with the password stored in pain text in the [Datum.yml](../source/Datum.yml). 

```yml
DatumHandlers:
  Datum.ProtectedData::ProtectedDatum:
    CommandOptions:
      PlainTextPassword: SomeSecret
```

This is obviously not secure. This short guide explains how to switch from simple password encryption to certificate-based encryption.

## 1.1. Import the module `Helpers.psm1`

To make things easier there are prepared functions in the [Helpers.psm1 module](../lab//Helpers.psm1). Import the module:

```powershell
Import-Module -Name .\lab\Helpers.psm1
```

## 1.2. Create a Document Encryption Certificate

If you don't have a document encryption certificate and no certificate authority to request it from, us the following command to create a self-signed one:

```powershell
New-DscDocumentEncryptionCertificate -Store LocalMachine -PassThru
```

The new certificate was stored in the current user's certificate store and has the name `DscEncryptionCert`.

> Note: You can select a different name for your certificate. You can also store it in the local machine's certificate store if this is more convenient.

## 1.3. Update the `Datum.yml` file

Please make note of the thumbprint of the certificate you have created in the previous step. 

Remove or comment out the `PlainTextPassword` key and add the key `Certificat` with the certificate thumbprint like this to the `CommandOptions` section:

```yml
DatumHandlers:
  Datum.ProtectedData::ProtectedDatum:
    CommandOptions:
      #PlainTextPassword: SomeSecret
      Certificate: 886B7F8684F9D13EE4FFBB0D5CF80E3AA156CE0D
```

## 1.4. Update the existing Credentials

The credentials important for starting and now securing this project are in the file [Azure.yml](../source/Global/Azure.yml). They are encypted with the password configured in the [Datum.yml](../source/Datum.yml) file.

First, convert this password into a secure string and store it in a variable. Then read the data of the [Azure.yml](../source/Global/Azure.yml) file and store it as well.

```powershell
$pass = 'SomeSecret' | ConvertTo-SecureString -AsPlainText -Force
$data = Get-Content .\source\Global\Azure.yml | ConvertFrom-Yaml
```

The following command must be done for each environment you have configured in the [Azure.yml](../source/Global/Azure.yml) file. Here only the dev environment is covered.

```powershell
$secret = $data.Environments.Dev.AzApplicationSecret | Unprotect-Datum -Password $pass
$secret | Protect-Datum -Certificate <CertificateThumbprint> -MaxLineLength 9999 | Set-Clipboard
```

You should have the secret now encrypted with your certificate in the clipboard. Now replace the old value with the new one using the Visual Studio Editor.

## 1.5. Test your new Encrypted Secrets

The section for the datum handler `Datum.ProtectedData` in the file [Datum.yml](../source/Datum.yml) should look like this:

```yml
DatumHandlers:
  Datum.ProtectedData::ProtectedDatum:
    CommandOptions:
      Certificate: <CertificateThumbprint>
```

As there is no plain text password defined anymore, your old credentials should now longer work as we no longer know the password they have been encrypted with. But the new ones should work and we should be able to decrypt them with the certificate defined here.

To prepare the build environment, run the build script:

```powershell
.\build.ps1 -Tasks noop
```

Then read the Datum structure directory with this command:

```powershell
$d = New-DatumStructure -DefinitionFile .\source\Datum.yml
$d.Global.Azure.Environments.Dev.AzApplicationSecret
```

If you access the key `AzApplicationSecret`, you should see the application secret and not a string like `[ENC=PE9ianMgVmVyc2lvbj...`.

Finally you can use the script [11 Test Connection.ps1](../lab//11%20Test%20Connection.ps1) to test connecting to your Azure tenants.

## Update Remaining Credentials

Finally, update all other credentials in the same way. Very likely you have an encrypted personal access token for Azure DevOps in the file [ProjectSettings.yml](../source/Global/ProjectSettings.yml). In the same file, there is also a password used for configuring the Azure DevOps build workers.
