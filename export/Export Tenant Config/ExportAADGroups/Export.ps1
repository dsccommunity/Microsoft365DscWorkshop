$param = @{
    Components = "AADGroup", 'O365Group' #, "AADAuthorizationPolicy", "AADConditionalAccessPolicy", "AADGroupLifecyclePolicy", "AADGroupsNamingPolicy", "AADGroupsSettings", "AADNamedLocationPolicy", "AADRoleSetting", "AADTokenLifetimePolicy"
    ManagedIdentity = $true
    TenantId = 'b246c1af-87ab-41d8-9812-83cd5ff534cb'
    #ApplicationId = '7365c036-169b-4d0b-907a-513eca20f6aa'
    #CertificateThumbprint = 'dec3141c225b5fd8fe0fee87547e4ce2c71c7fa5'
    Path = $PSScriptRoot
}

Export-M365DSCConfiguration @param

#Get-M365DSCCompiledPermissionList -ResourceNameList "AADGroup", 'O365Group' -AccessType Read -PermissionType Application

#Connect-ExchangeOnline -Organization MngEnvMCAP576786.onmicrosoft.com -ManagedIdentity -ManagedIdentityAccountId c123b7ea-55b5-4c67-ad29-880aacdb61b2 #35eaf03a-86ac-4e6e-92c4-374d61d1711c
