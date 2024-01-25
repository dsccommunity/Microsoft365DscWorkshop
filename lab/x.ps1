function Connect-Azure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory = $true)]
        [securestring]$ServicePrincipalSecret,

        [Parameter()]
        [string[]]$Scopes = ('RoleManagement.ReadWrite.Directory', 'Directory.ReadWrite.All')
    )

    $cred = New-Object pscredential($ServicePrincipalId, $ServicePrincipalSecret)
    try {
        $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $TenantId -ErrorAction Stop
        Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"
    }
    catch {
        Write-Error "Failed to connect to Azure tenant '$TenantId' / subscription '$SubscriptionId' with service principal '$ServicePrincipalId'. The error was: $($_.Exception.Message)"
        return
    }

    try {
        Connect-MgGraph -ClientSecretCredential $cred -TenantId $TenantId -NoWelcome
        $graphContext = Get-MgContext
        Write-Host "Connected to Graph API '$($graphContext.TenantId)' with account '$($graphContext.ClientId)'"
    }
    catch {
        Write-Error "Failed to connect to Graph API of tenant '$TenantId' with service principal '$ServicePrincipalId'. The error was: $($_.Exception.Message)"
        return
    }
}

$secret = 'ZfL8Q~KYSBbuoIbAPN7E4DzABb5AxS9pvi~z3adp' | ConvertTo-SecureString -AsPlainText -Force
Connect-Azure -TenantId b246c1af-87ab-41d8-9812-83cd5ff534cb -SubscriptionId 9522bd96-d34f-4910-9667-0517ab5dc595 -ServicePrincipalId 786ac54b-fa5c-4be3-83dc-1d74615f3aaa -ServicePrincipalSecret $secret