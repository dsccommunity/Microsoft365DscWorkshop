$TenantId = 'MngEnvMCAP576786.onmicrosoft.com'

Export-M365DSCConfiguration -Components @("AADAdministrativeUnit", "AADConditionalAccessPolicy") -ManagedIdentity -TenantId $TenantId -Path C:\Export