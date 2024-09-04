Connect-M365Dsc -TenantId b246c1af-87ab-41d8-9812-83cd5ff534cb -TenantName MngEnvMCAP576786.onmicrosoft.com -SubscriptionId 9522bd96-d34f-4910-9667-0517ab5dc595

1. Create a app registration in your teanant if not already done.
2. Create a certificate and upload it to the app registration.
   1. .\build.ps1 -Tasks labinit
   2. $cert = New-M365DSCSelfSignedCertificate -Store LocalMachine -PassThru
   3. [System.IO.File]::WriteAllBytes('.\AuthCert.cer', $cert.Export('Cert'))
3. $permissions = Get-M365DSCCompiledPermissionList2 -AccessType Read
4. $id = Get-M365DscIdentity -Name Export
5. Set-ServicePrincipalAppPermissions -DisplayName Export -Permissions $permissions
6. Export-M365DSCConfiguration -Components AADApplication -ApplicationId 1279affe-7506-4b42-ae23-f6f025fb692d -TenantId MngEnvMCAP576786.onmicrosoft.com -CertificateThumbprint 0769225665d722caba154ae32c3894678ddc7cc7 -Path .\temp\

Create a 

https://github.com/KingslandConsulting/Kingsland.MofParser
