function Get-ServicePrincipalAppPermissions
{
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'byId')]
        [string]$ObjectId,

        [Parameter(Mandatory = $true, ParameterSetName = 'byDisplayName')]
        [string]$DisplayName
    )

    $principal = if ($ObjectId)
    {
        Get-MgServicePrincipal -Filter "Id eq 'ObjectId'" -ErrorAction SilentlyContinue
    }
    else
    {
        Get-MgServicePrincipal -Filter "DisplayName eq '$DisplayName'" -ErrorAction SilentlyContinue
    }

    if (-not $principal)
    {
        Write-Error 'Service principal not found'
        return
    }

    $appRoles = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $principal.Id

    foreach ($appRole in $appRoles)
    {
        $api = Get-MgServicePrincipal -Filter "DisplayName eq '$($appRole.ResourceDisplayName)'"
        $apiPermission = $api.AppRoles | Where-Object Id -EQ $appRole.AppRoleId

        [pscustomobject][ordered]@{
            ApiAppId          = $api.AppId
            ApiId             = $api.Id
            ApiRoleId         = $apiPermission.Id
            ApiDisplayName    = $api.DisplayName
            ApiPermissionName = $apiPermission.Value
            PermissionType    = $apiPermission.AllowedMemberTypes -join ', '
        }
    }

}

function Set-ServicePrincipalAppPermissions
{
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'byId')]
        [string]$ObjectId,

        [Parameter(Mandatory = $true, ParameterSetName = 'byDisplayName')]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [object[]]$Permissions,

        [Parameter()]
        [switch]$PassThru
    )

    $principal = if ($ObjectId)
    {
        Get-MgServicePrincipal -Filter "Id eq 'ObjectId'" -ErrorAction SilentlyContinue
    }
    else
    {
        Get-MgServicePrincipal -Filter "DisplayName eq '$DisplayName'" -ErrorAction SilentlyContinue
    }

    if (-not $principal)
    {
        Write-Error "Service principal '$($principal.DisplayName)' not found"
        return
    }

    if ($principal.Count -gt 1)
    {
        Write-Error "Multiple service principals with display name '$DisplayName' found"
        return
    }

    [void]$PSBoundParameters.Remove('Permissions')
    [void]$PSBoundParameters.Remove('PassThru')

    $existingPermissions = Get-ServicePrincipalAppPermissions @PSBoundParameters

    foreach ($p in $permissions)
    {
        if (($existingPermissions | Where-Object ApiRoleId -EQ $p.ApiRoleId) -or (-not $p.ApiRoleId))
        {
            Write-Verbose "Permission $($p.ApiPermissionName) ($($p.ApiRoleId)) already exists for $($p.ApiDisplayName)"
            continue
        }

        Write-Verbose "Adding Permission $($p.ApiPermissionName) ($($p.ApiRoleId)) for $($p.ApiDisplayName)"
        $params = @{
            ServicePrincipalId = $principal.Id
            AppRoleId          = $p.ApiRoleId
            ResourceId         = $p.ApiId
            PrincipalId        = $principal.Id
        }
        New-MgServicePrincipalAppRoleAssignment @params | Out-Null
    }

    if ($PassThru)
    {
        Get-ServicePrincipalAppPermissions @PSBoundParameters
    }

}

function Get-M365DSCCompiledPermissionList2
{
    param ()

    $m365GraphPermissionList = ((Get-M365DSCCompiledPermissionList -ResourceNameList (Get-M365DSCAllResources)).Update)

    $resourceAppIds = @{
        Graph      = '00000003-0000-0000-c000-000000000000'
        SharePoint = '00000003-0000-0ff1-ce00-000000000000'
        Exchange   = '00000002-0000-0ff1-ce00-000000000000'
    }

    $servicePrincipals = @{
        Graph      = Get-MgServicePrincipal -Filter "AppId eq '$($resourceAppIds.Graph)'"
        SharePoint = Get-MgServicePrincipal -Filter "AppId eq '$($resourceAppIds.SharePoint)'"
        Exchange   = Get-MgServicePrincipal -Filter "AppId eq '$($resourceAppIds.Exchange)'"
    }

    $m365GraphApplicationPermissionList = $m365GraphPermissionList | Where-Object { $_.Permission.Type -ne 'Delegated' }

    foreach ($permission in $m365GraphApplicationPermissionList.GetEnumerator())
    {
        $servicePrincipal = $servicePrincipals."$($permission.Api)"

        $appRole = $servicePrincipal.AppRoles | Where-Object -FilterScript { $_.Value -eq $permission.Permission.Name }

        [pscustomobject][ordered]@{
            ApiAppId          = $servicePrincipal.AppId
            ApiId             = $servicePrincipal.Id
            ApiRoleId         = $appRole.Id
            ApiDisplayName    = $servicePrincipal.DisplayName
            ApiPermissionName = $permission.Permission.Name
            PermissionType    = $permission.Permission.Type
        }

    }
}

function Connect-Azure
{
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
        [string[]]$Scopes = ('RoleManagement.ReadWrite.Directory',
            'Directory.ReadWrite.All',
            'Application.ReadWrite.All'
        )
    )

    $cred = New-Object pscredential($ServicePrincipalId, $ServicePrincipalSecret)
    try
    {
        $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $TenantId -ErrorAction Stop
        Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"
    }
    catch
    {
        Write-Error "Failed to connect to Azure tenant '$TenantId' / subscription '$SubscriptionId' with service principal '$ServicePrincipalId'. The error was: $($_.Exception.Message)"
        return
    }

    try
    {
        Connect-MgGraph -ClientSecretCredential $cred -TenantId $TenantId -NoWelcome
        $graphContext = Get-MgContext
        Write-Host "Connected to Graph API '$($graphContext.TenantId)' with account '$($graphContext.ClientId)'"
    }
    catch
    {
        Write-Error "Failed to connect to Graph API of tenant '$TenantId' with service principal '$ServicePrincipalId'. The error was: $($_.Exception.Message)"
        return
    }
}
