$param = @{
    #Components            = 'AADGroup', 'O365Group' #, "AADAuthorizationPolicy", "AADConditionalAccessPolicy", "AADGroupLifecyclePolicy", "AADGroupsNamingPolicy", "AADGroupsSettings", "AADNamedLocationPolicy", "AADRoleSetting", "AADTokenLifetimePolicy"
    ManagedIdentity       = $true
    #CertificateThumbprint = '1A1BC506C9A9E65B520F627398EC01A8ABF2DF70'
    #ApplicationId         = '94079e1e-902f-41d2-a3c1-8f2a734bae42'
    #TenantId              = '8fe898b0-f28d-4917-96bf-048e7e38a5eb'
}

Export-M365DSCConfiguration @param

#$sec = 'I4M8Q~LR9D3x275JTu62ylEQqjs~uKqmBzDC9aaz'
#Export-M365DSCConfiguration -Components @("AADApplication") -ApplicationSecret $sec -ApplicationId 94079e1e-902f-41d2-a3c1-8f2a734bae42 -TenantId 8fe898b0-f28d-4917-96bf-048e7e38a5eb

#Get-M365DSCCompiledPermissionList -ResourceNameList "AADGroup", 'O365Group' -AccessType Read -PermissionType Application

#Connect-ExchangeOnline -Organization MngEnvMCAP576786.onmicrosoft.com -ManagedIdentity -ManagedIdentityAccountId c123b7ea-55b5-4c67-ad29-880aacdb61b2 #35eaf03a-86ac-4e6e-92c4-374d61d1711c
