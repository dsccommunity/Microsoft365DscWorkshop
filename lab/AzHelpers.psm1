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
            ApiAppId             = $api.AppId
            ApiId                = $api.Id
            ApiRoleId            = $apiPermission.Id
            ApiDisplayName       = $api.DisplayName
            ApiPermissionName    = $apiPermission.Value
            PermissionType       = $apiPermission.AllowedMemberTypes -join ', '
            AppRoleAssignmentId  = $appRole.Id
            PrincipalDisplayName = $appRole.PrincipalDisplayName
            PrincipalId          = $appRole.PrincipalId
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

function Remove-ServicePrincipalAppPermissions
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
            Write-Verbose "Permission $($p.ApiPermissionName) ($($p.ApiRoleId)) exists for $($p.ApiDisplayName) and will be removed."

            $params = @{
                ServicePrincipalId = $principal.Id
                AppRoleId          = $p.ApiRoleId
                ResourceId         = $p.ApiId
                PrincipalId        = $principal.Id
            }

            $GraphApp = Get-MgServicePrincipal -Filter "AppId eq '$($p.ApiAppId)'"
            $Role = $GraphApp.AppRoles | Where-Object Id -EQ $p.ApiRoleId
            $AppRoleAssignment = @{
                'PrincipalId' = $principal.Id
                'ResourceId'  = $GraphApp.Id
                'AppRoleId'   = $Role.Id 
            }

            Remove-MgServicePrincipalAppRoleAssignment -AppRoleAssignmentId $p.AppRoleAssignmentId -ServicePrincipalId $principal.Id
            Write-Host "Removed role assignment / permission '$($p.ApiPermissionName)' for principal '$($p.PrincipalDisplayName)' (AppRoleAssignmentId was '$($p.AppRoleAssignmentId)')"

        }
        else
        {
            Write-Verbose "Permission $($p.ApiPermissionName) ($($p.ApiRoleId)) does not exist for $($p.ApiDisplayName) and cannot be removed."
        }
    
    }

    if ($PassThru)
    {
        Get-ServicePrincipalAppPermissions @PSBoundParameters
    }

}

function Get-M365DSCCompiledPermissionList2
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Update', 'Read')]
        [string]$AccessType = 'Update'
    )

    $m365GraphPermissionList = Get-M365DSCCompiledPermissionList -ResourceNameList (Get-M365DSCAllResources) -AccessType $AccessType -PermissionType Delegated

    $m365GraphPermissionList += @{ 
        PermissionName = if ($AccessType -eq 'Update')
        {                
            'Sites.FullControl.All' 
        }
        else
        {
            'Sites.Read.All'
        } 
        API = 'SharePoint' 
    }
    
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

    $result = foreach ($permission in $m365GraphPermissionList)
    {
        $servicePrincipal = $servicePrincipals."$($permission.Api)"

        $appRole = $servicePrincipal.AppRoles | Where-Object -FilterScript { $_.Value -eq $permission.PermissionName }

        [pscustomobject][ordered]@{
            ApiAppId          = $servicePrincipal.AppId
            ApiId             = $servicePrincipal.Id
            ApiRoleId         = $appRole.Id
            ApiDisplayName    = $servicePrincipal.DisplayName
            ApiPermissionName = $permission.PermissionName
            PermissionType    = 'Delegated'
        }
    }

    if ($AccessType -eq 'Read')
    {
        $result | Where-Object { $_.ApiPermissionName -notlike '*FullControl*' -and $_.ApiPermissionName -notlike '*Write*' }
    }
    else
    {
        $result
    }
}

function Get-GraphPermission
{
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$PermissionName
    )

    $servicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
    $appRoles = $servicePrincipal.AppRoles | Where-Object { $_.Permission.Type -ne 'Delegated' }

    foreach ($Permission in $PermissionName)
    {
        $appRole = $appRoles | Where-Object Value -EQ $Permission

        if (-not $appRole)
        {
            Write-Warning "Permission '$Permission' not found"
            continue
        }
        
        [pscustomobject][ordered]@{
            ApiAppId          = $servicePrincipal.AppId
            ApiId             = $servicePrincipal.Id
            ApiRoleId         = $appRole.Id
            ApiDisplayName    = $servicePrincipal.DisplayName
            ApiPermissionName = $appRole.Value
            PermissionType    = $appRole.AllowedMemberTypes[0]
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
            'Application.ReadWrite.All',
            'Group.ReadWrite.All',
            'GroupMember.ReadWrite.All',
            'User.ReadWrite.All'
        )
    )

    $cred = New-Object pscredential($ServicePrincipalId, $ServicePrincipalSecret)

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
}

function Connect-EXO
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$TenantName,

        [Parameter(Mandatory = $true)]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$ServicePrincipalSecret
    )

    $tokenBody = @{     
        Grant_Type    = 'client_credentials' 
        Scope         = 'https://outlook.office365.com/.default'
        Client_Id     = $ServicePrincipalId
        Client_Secret = $ServicePrincipalSecret
    }  

    try
    {
        $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $tokenBody

        Connect-ExchangeOnline -AccessToken $tokenResponse.access_token -Organization $TenantName -ShowBanner:$false 

        Write-Host "Successfully connected to Exchange Online of tenant '$TenantName' with service principal '$ServicePrincipalId'"
    }
    catch
    {
        Write-Error "Failed to connect to Exchange Online of tenant '$TenantName' with service principal '$ServicePrincipalId'. The error was: $($_.Exception.Message)"
        return
    }
}
