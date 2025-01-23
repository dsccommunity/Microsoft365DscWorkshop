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
        Write-Error "Service principal named '$DisplayName' or with the Object ID '$ObjectId' could not found"
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
            Write-Verbose "Permission '$($p.ApiPermissionName)' ($($p.ApiRoleId)) already exists for '$($p.ApiDisplayName)'"
            continue
        }

        Write-Verbose "Adding Permission '$($p.ApiPermissionName)' ($($p.ApiRoleId)) for '$($p.ApiDisplayName)'"
        $params = @{
            ServicePrincipalId = $principal.Id
            AppRoleId          = $p.ApiRoleId
            ResourceId         = $p.ApiId
            PrincipalId        = $principal.Id
        }
        New-MgServicePrincipalAppRoleAssignment @params -ErrorAction SilentlyContinue -ErrorVariable assignmentError | Out-Null
        if ($assignmentError.Count -gt 0)
        {
            if ($assignmentError.Exception.Message -like '*already exists*')
            {
                Write-Verbose "Permission '$($p.ApiPermissionName)' ($($p.ApiRoleId)) already exists for '$($p.ApiDisplayName)'"
            }
            else
            {
                Write-Error -ErrorRecord $_
            }
        }
        else
        {
            Write-Verbose "Added role assignment / permission '$($p.ApiPermissionName)' for principal '$($p.PrincipalDisplayName)'"
        }
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
        if ($roleAssignment = $existingPermissions | Where-Object { $_.ApiRoleId -eq $p.ApiRoleId -and $_.ApiAppId -eq $p.ApiAppId })
        {
            if (-not $roleAssignment)
            {
                Write-Warning "Role assignment / permission '$($p.ApiPermissionName)' ($($p.ApiRoleId)) does not exist for '$($p.ApiDisplayName)' and cannot be removed."
                continue
            }

            Remove-MgServicePrincipalAppRoleAssignment -AppRoleAssignmentId $roleAssignment.AppRoleAssignmentId -ServicePrincipalId $principal.Id -ErrorAction SilentlyContinue
            Write-Host "Removed role assignment / permission '$($roleAssignment.ApiPermissionName)' for principal '$($principal.DisplayName)' (AppRoleAssignmentId was '$($roleAssignment.AppRoleAssignmentId)')"

        }
        else
        {
            Write-Verbose "Permission '$($p.ApiPermissionName)' ($($p.ApiRoleId)) does not exist for '$($p.ApiDisplayName)' and cannot be removed."
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

    $m365GraphPermissionList = Get-M365DSCCompiledPermissionList -ResourceNameList (Get-M365DSCAllResources) -ErrorAction Stop

    $resourceAppIds = @{
        Graph      = '00000003-0000-0000-c000-000000000000'
        SharePoint = '00000003-0000-0ff1-ce00-000000000000'
        Exchange   = '00000002-0000-0ff1-ce00-000000000000'
    }

    try
    {
        $servicePrincipals = @{
            Graph      = Get-MgServicePrincipal -Filter "AppId eq '$($resourceAppIds.Graph)'" -ErrorAction Stop
            SharePoint = Get-MgServicePrincipal -Filter "AppId eq '$($resourceAppIds.SharePoint)'" -ErrorAction Stop
            Exchange   = Get-MgServicePrincipal -Filter "AppId eq '$($resourceAppIds.Exchange)'" -ErrorAction Stop
        }
    }
    catch
    {
        Write-Error "Failed to retrieve service principals for Graph, SharePoint, and Exchange. The error was: $($_.Exception.Message)"
        return
    }

    $permissions = $m365GraphPermissionList.$AccessType

    if ($AccessType -eq 'Read')
    {
        $sitesReadAllGet = GraphPermission -PermissionName Sites.Read.All
        $permissions += @{
            API        = 'Graph'
            Permission = @{
                Name = $sitesReadAllGet.ApiPermissionName
                Type = $sitesReadAllGet.PermissionType
            }
        }
    }

    $result = foreach ($permission in $permissions)
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
    param (
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
    param (
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

enum M365DscIdentityType
{
    Application
    ManagedIdentity
}

class M365DscIdentity
{
    [string]$DisplayName
    [string]$Id
    [string]$AppId
    [string]$AppPrincipalId
    [string]$ExchangePrincipalId
    [M365DscIdentityType]$ServicePrincipalType
    [object]$Secret
    [string]$CertificateThumbprint

    M365DscIdentity([string]$DisplayName, [string]$Id, [string]$AppId, [string]$AppPrincipalId, [string]$ExchangePrincipalId, [M365DscIdentityType]$ServicePrincipalType, [object]$Secret)
    {
        $this.DisplayName = $DisplayName
        $this.Id = $Id
        $this.AppId = $AppId
        $this.AppPrincipalId = $AppPrincipalId
        $this.ExchangePrincipalId = $ExchangePrincipalId
        $this.ServicePrincipalType = $ServicePrincipalType
        $this.Secret = $Secret
    }

    M365DscIdentity([string]$DisplayName, [string]$Id, [string]$AppId, [string]$AppPrincipalId, [string]$ExchangePrincipalId, [M365DscIdentityType]$ServicePrincipalType, [string]$CertificateThumbprint)
    {
        $this.DisplayName = $DisplayName
        $this.Id = $Id
        $this.AppId = $AppId
        $this.AppPrincipalId = $AppPrincipalId
        $this.ExchangePrincipalId = $ExchangePrincipalId
        $this.ServicePrincipalType = $ServicePrincipalType
        $this.CertificateThumbprint = $CertificateThumbprint
    }

    M365DscIdentity([string]$DisplayName, [string]$Id, [string]$AppId, [string]$AppPrincipalId, [string]$ExchangePrincipalId, [M365DscIdentityType]$ServicePrincipalType)
    {
        $this.DisplayName = $DisplayName
        $this.Id = $Id
        $this.AppId = $AppId
        $this.AppPrincipalId = $AppPrincipalId
        $this.ExchangePrincipalId = $ExchangePrincipalId
        $this.ServicePrincipalType = $ServicePrincipalType
    }
}

function New-M365DscIdentity
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [string]$Name,

        [Parameter(ParameterSetName = 'AppSecret')]
        [switch]$GenereateAppSecret,

        [Parameter(ParameterSetName = 'Certificate')]
        [switch]$GenereateCertificate,

        [Parameter(ParameterSetName = 'AppSecret')]
        [Parameter(ParameterSetName = 'Certificate')]
        [Parameter(ParameterSetName = 'Default')]
        [switch]$OnlyServicePrincipals,

        [Parameter(ParameterSetName = 'AppSecret')]
        [Parameter(ParameterSetName = 'Certificate')]
        [Parameter(ParameterSetName = 'Default')]
        [switch]$PassThru
    )

    if (-not $OnlyServicePrincipals)
    {
        if (-not ($appRegistration = Get-MgApplication -Filter "displayName eq '$Name'" -ErrorAction SilentlyContinue))
        {
            Write-Verbose "Did not find application '$Name' in environment."
            Write-Verbose "Creating application '$Name'."

            $appRegistration = New-MgApplication -DisplayName $Name

            Update-MgApplication -ApplicationId $appRegistration.Id -SignInAudience AzureADMyOrg
        }
        else
        {
            Write-Verbose "Application '$Name' already exists in environment."
        }

        if ($GenereateAppSecret)
        {
            $passwordCred = @{
                displayName = 'Secret'
                endDateTime = (Get-Date).AddMonths(12)
            }
            Write-Verbose "Updating application '$($appRegistration.DisplayName)' (Id: $($appRegistration.Id)) with new secret."
            $clientSecret = Add-MgApplicationPassword -ApplicationId $appRegistration.Id -PasswordCredential $passwordCred
        }
        elseif ($GenereateCertificate)
        {
            $certificate = New-M365DSCSelfSignedCertificate -Subject $Name -Store LocalMachine -PassThru

            if ($certificate.Count -gt 1)
            {
                Write-Error 'More than one certificate was generated. This is not expected. Please investigate.'
                return
            }

            $bytes = $certificate.Export('Cert')
            $params = @{
                keyCredentials = @(
                    @{
                        type        = 'AsymmetricX509Cert'
                        usage       = 'Verify'
                        key         = $bytes
                        displayName = 'GeneratedByM365DscWorkshop'
                    }
                )
            }

            Write-Host "Updating application '$($appRegistration.DisplayName)' (Id: $($appRegistration.Id)) with new certificate (thumbprint: $($certificate.Thumbprint))."
            Update-MgApplication -ApplicationId $appRegistration.Id -BodyParameter $params

            $identity = $environment.Identities | Where-Object Name -EQ $Name
            if ($identity.CertificateThumbprint -eq '<AutoGeneratedLater>')
            {
                $identity.CertificateThumbprint = $certificate.Thumbprint
            }
        }
    }

    if (-not ($appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$Name'" -ErrorAction SilentlyContinue))
    {
        Write-Verbose "Creating service principal for application '$Name'."
        $appPrincipal = New-MgServicePrincipal -AppId $appRegistration.AppId
    }

    if ($exchangeServicePrincipal = Get-ServicePrincipal | Where-Object DisplayName -EQ $Name)
    {
        Write-Verbose "The EXO service principal for application '$Name' already exists."
    }
    else
    {
        Write-Verbose "Creating the EXO service principal for application '$Name'."
        $retryCount = 5
        while ($retryCount -gt 0)
        {
            try
            {
                $exchangeServicePrincipal = New-ServicePrincipal -AppId $appPrincipal.AppId -ObjectId $appPrincipal.Id -DisplayName $Name -ErrorAction Stop
                break
            }
            catch
            {
                Write-Warning "Failed to create the EXO service principal for application '$Name'. Retrying in 10 seconds."
                Start-Sleep -Seconds 10
                $retryCount--
            }
        }
    }

    if ($PassThru)
    {
        [M365DscIdentity]::new($appRegistration.DisplayName,
            $appRegistration.Id,
            $appRegistration.AppId,
            $appPrincipal.Id,
            $exchangeServicePrincipal.Id,
            $appPrincipal.ServicePrincipalType,
            $clientSecret)
    }
}

function Remove-M365DscIdentity
{
    [CmdletBinding(DefaultParameterSetName = 'byName')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'byName')]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'byIdentity')]
        [M365DscIdentity]$Identity
    )

    if ($psCmdlet.ParameterSetName -eq 'byName')
    {
        $identity = Get-M365DscIdentity -Name $Name
    }

    if ($identity.ExchangePrincipalId)
    {
        Write-Verbose "Removing EXO service principal for application '$($Identity.DisplayName)'."
        Remove-ServicePrincipal -Identity $($Identity.DisplayName) -Confirm:$false
    }
    else
    {
        Write-Verbose "EXO service principal for application '$($Identity.DisplayName)' does not exist."
    }

    if ($null -ne $identity)
    {
        Write-Verbose "Removing application '$($Identity.DisplayName)'."
        Remove-MgApplication -ApplicationId $identity.Id
    }
    else
    {
        Write-Verbose "Application '$($Identity.DisplayName)' does not exist."
    }
}

function Get-M365DscIdentity
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try
    {
        $appRegistration = Get-MgApplication -Filter "displayName eq '$Name'" -ErrorAction Stop
    }
    catch [Microsoft.Graph.PowerShell.AuthenticationException]
    {
        Write-Error -Message "You are not connected to the Microsoft Graph. Please run 'Connect-M365Dsc'." -Exception $_.Exception -ErrorAction Stop
    }

    if ($appRegistration)
    {
        Write-Verbose "Found application '$Name' with Id '$($appRegistration.Id)' and AppId '$($appRegistration.AppId)'."
        $appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$Name'" -ErrorAction SilentlyContinue
        $exchangeServicePrincipal = Get-ServicePrincipal -Identity $Name -ErrorAction SilentlyContinue

        if ($appRegistration.KeyCredentials.Count -gt 0)
        {
            if ($appRegistration.KeyCredentials.Count -ne 1)
            {
                Write-Host "Application '$Name' has more than one certificate. This is not expected. Only the first certificate will be returned."
            }

            $certificate = $appRegistration.KeyCredentials[0]
            $certificateThumbPrint = [System.Convert]::ToBase64String($certificate.CustomKeyIdentifier)

            [M365DscIdentity]::new($appRegistration.DisplayName,
                $appRegistration.Id,
                $appRegistration.AppId,
                $appPrincipal.Id,
                $exchangeServicePrincipal.Id,
                $appPrincipal.ServicePrincipalType,
                $certificateThumbPrint)
        }
        else
        {
            [M365DscIdentity]::new($appRegistration.DisplayName,
                $appRegistration.Id,
                $appRegistration.AppId,
                $appPrincipal.Id,
                $exchangeServicePrincipal.Id,
                $appPrincipal.ServicePrincipalType)
        }
    }
    elseif ($principal = Get-MgServicePrincipal -Filter "DisplayName eq '$Name'" -ErrorAction SilentlyContinue)
    {
        Write-Verbose "Found principal '$Name' with Id '$($principal.Id)' and AppId '$($principal.AppId)'."
        $exchangeServicePrincipal = Get-ServicePrincipal -Identity $Name -ErrorAction SilentlyContinue

        [M365DscIdentity]::new($principal.DisplayName,
            $null,
            $principal.AppId,
            $principal.Id,
            $exchangeServicePrincipal.Id,
            $principal.ServicePrincipalType)
    }
    else
    {
        Write-Verbose "Application '$Name' does not exist in environment."
    }
}

function Test-M365DscConnection
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter()]
        [string]$SubscriptionId
    )

    $azContext = Get-AzContext
    $mgContext = Get-MgContext
    $exoConnection = Get-ConnectionInformation

    $isConnected = $true

    if ($null -eq $azContext)
    {
        Write-Error "Azure context is not set. Please run 'Connect-AzAccount'."
        $isConnected = $false
    }

    if ($null -eq $mgContext)
    {
        Write-Error "Microsoft Graph context is not set. Please run 'Connect-MgGraph'."
        $isConnected = $false
    }

    if ($null -eq $exoConnection)
    {
        Write-Error "Exchange Online connection is not set. Please run 'Connect-ExchangeOnline'."
        $isConnected = $false
    }

    if (-not $isConnected)
    {
        return $false
    }

    if ($azContext.Tenant.Id -ne $TenantId)
    {
        Write-Error "Azure context tenant ID '$($azContext.Tenant.Id)' does not match the provided tenant ID '$TenantId'."
        $isConnected = $false
    }
    else
    {
        Write-Host "Azure context tenant ID '$($azContext.Tenant.Id)' matches the provided tenant ID."
    }

    if ([string]::IsNullOrEmpty($SubscriptionId))
    {
        Write-Host 'Azure context subscription ID is not set.'
    }
    elseif ($azContext.Subscription.Id -ne $SubscriptionId)
    {
        Write-Error "Azure context subscription ID '$($azContext.Subscription.Id)' does not match the provided subscription ID '$SubscriptionId'."
        $isConnected = $false
    }
    else
    {
        Write-Host "Azure context subscription ID '$($azContext.Subscription.Id)' matches the provided subscription ID."
    }

    if ($mgContext.TenantId -ne $TenantId)
    {
        Write-Error "Microsoft Graph context tenant ID does not match the provided tenant ID: '$TenantId'."
        $isConnected = $false
    }
    else
    {
        Write-Host 'Microsoft Graph context tenant ID '$($mgContext.TenantId)' matches the provided tenant ID.'
    }

    if ($exoConnection.TenantId -ne $TenantId)
    {
        Write-Error "Exchange Online connection tenant ID '$($exoConnection.TenantId)' does not match the provided tenant ID: '$TenantId'."
        $isConnected = $false
    }
    else
    {
        Write-Host "Exchange Online connection tenant ID '$($exoConnection.TenantId)' matches the provided tenant ID."
    }

    return $isConnected
}

function Connect-M365DscAzure
{
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'AppSecret')]
        [Parameter(ParameterSetName = 'Certificate')]
        [Parameter(ParameterSetName = 'Interactive')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [securestring]$ServicePrincipalSecret,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [string]$CertificateThumbprint,

        [Parameter()]
        [string[]]$Scopes = ('RoleManagement.ReadWrite.Directory',
            'Directory.ReadWrite.All',
            'Application.ReadWrite.All',
            'Group.ReadWrite.All',
            'GroupMember.ReadWrite.All',
            'User.ReadWrite.All'
        )
    )

    if ($PSCmdlet.ParameterSetName -eq 'AppSecret')
    {
        $cred = New-Object pscredential($ServicePrincipalId, $ServicePrincipalSecret)
    }

    try
    {
        if ($PSCmdlet.ParameterSetName -eq 'AppSecret')
        {
            $param = @{
                ServicePrincipal = $true
                Credential       = $cred
                Tenant           = $TenantId
                ErrorAction      = 'Stop'
                WarningAction    = 'Ignore'
            }
            $subscription = Connect-AzAccount @param *>&1
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Certificate')
        {
            $param = @{
                Tenant                = $TenantId
                ApplicationId         = $ServicePrincipalId
                CertificateThumbprint = $CertificateThumbprint
                ErrorAction           = 'Stop'
                WarningAction         = 'Ignore'
            }
            $subscription = Connect-AzAccount @param *>&1
        }
        else
        {
            $param = @{
                Tenant        = $TenantId
                ErrorAction   = 'Stop'
                WarningAction = 'Ignore'
            }
            if ($SubscriptionId)
            {
                $param.SubscriptionId = $SubscriptionId
            }

            $subscription = if ($SubscriptionId)
            {
                Connect-AzAccount @param *>&1
            }
            else
            {
                Connect-AzAccount @param
            }

        }
        Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name)' ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"
    }
    catch
    {
        Write-Error "Failed to connect to Azure tenant '$TenantId' / subscription '$SubscriptionId'. The error was: $($_.Exception.Message)."
        return
    }

    try
    {
        $token = Get-AzAccessToken -ResourceTypeName MSGraph
        Connect-MgGraph -AccessToken ($token.Token | ConvertTo-SecureString -AsPlainText -Force) -NoWelcome -ErrorAction Stop
        $graphContext = Get-MgContext
        Write-Host "Connected to Graph API '$($graphContext.TenantId)' with account '$($graphContext.ClientId)'."
    }
    catch
    {
        Write-Error "Failed to connect to Graph API of tenant '$TenantId'. The error was: $($_.Exception.Message)."
        return
    }
    <#
    try {
        if ($PSCmdlet.ParameterSetName -eq 'AppSecret') {
            Connect-MgGraph -ClientSecretCredential $cred -TenantId $TenantId -NoWelcome -ErrorAction Stop | Out-Null
        }
        else {
            Connect-MgGraph -TenantId $TenantId -NoWelcome -ErrorAction Stop | Out-Null
        }

        $graphContext = Get-MgContext
        Write-Host "Connected to Graph API '$($graphContext.TenantId)' with account '$($graphContext.ClientId)'"
    }
    catch {
        Write-Error "Failed to connect to Graph API of tenant '$TenantId' with service principal '$ServicePrincipalId'. The error was: $($_.Exception.Message)"
        return
    }
    #>
}

function Connect-M365DscExchangeOnline
{
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive')]
        [string]$TenantId,

        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive')]
        [string]$TenantName,

        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [securestring]$ServicePrincipalSecret,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [string]$CertificateThumbprint
    )

    try
    {
        if ($PSCmdlet.ParameterSetName -eq 'AppSecret')
        {
            $tokenBody = @{
                Grant_Type    = 'client_credentials'
                Scope         = 'https://outlook.office365.com/.default'
                Client_Id     = $ServicePrincipalId
                Client_Secret = $ServicePrincipalSecret | ConvertFrom-SecureString -AsPlainText
            }

            $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $tokenBody

            Connect-ExchangeOnline -AccessToken $tokenResponse.access_token -Organization $TenantName -ShowBanner:$false
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Certificate')
        {
            Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppId $ServicePrincipalId -Organization $TenantName -ShowBanner:$false
        }
        else
        {
            Connect-ExchangeOnline -ShowBanner:$false
        }

        $connection = Get-ConnectionInformation

        if ($connection.TenantID -ne $TenantId)
        {
            Write-Error "Exchange Online connection tenant ID '$($connection.TenantID)' does not match the provided tenant ID: '$TenantId'."
            Disconnect-ExchangeOnline -Confirm:$false
            return
        }

        Write-Host "Successfully connected to Exchange Online of tenant '$($connection.TenantID)' with identity '$($connection.UserPrincipalName)'."
    }
    catch
    {
        Write-Error "Failed to connect to Exchange Online of tenant '$TenantName'. The error was: $($_.Exception.Message)."
        return
    }
}

function Connect-M365Dsc
{
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive')]
        [string]$TenantId,

        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive')]
        [string]$TenantName,

        [Parameter(ParameterSetName = 'AppSecret')]
        [Parameter(ParameterSetName = 'Certificate')]
        [Parameter(ParameterSetName = 'Interactive')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory = $true, ParameterSetName = 'AppSecret')]
        [securestring]$ServicePrincipalSecret,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [string]$CertificateThumbprint
    )

    Disconnect-M365Dsc -ErrorAction SilentlyContinue

    Write-Host 'Connecting to Azure, Microsoft Graph, and Exchange Online services.' -ForegroundColor Green
    $param = Sync-M365DSCParameter -Command (Get-Command -Name Connect-M365DscAzure) -Parameters $PSBoundParameters
    Connect-M365DscAzure @param -ErrorAction Stop

    $param = Sync-M365DSCParameter -Command (Get-Command -Name Connect-M365DscExchangeOnline) -Parameters $PSBoundParameters
    Connect-M365DscExchangeOnline @param -ErrorAction Stop
    Write-Host 'Connected to all services.' -ForegroundColor Green
}

function Disconnect-M365Dsc
{
    [CmdletBinding()]
    param ()

    Disconnect-ExchangeOnline -Confirm:$false
    Disconnect-MgGraph | Out-Null
    Disconnect-AzAccount | Out-Null
    Write-Host 'Disconnected from all services.'
}

function Add-M365DscIdentityPermission
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [M365DscIdentity]$Identity,

        [Parameter()]
        [ValidateSet('Update', 'Read')]
        [string]$AccessType = 'Update'
    )

    $azureContext = Get-AzContext

    if (-not $azureContext.Subscription.Id)
    {
        Write-Host 'No Azure subscription available. Skipping Azure permissions.' -ForegroundColor Yellow
    }
    else
    {
        Write-Host 'Adding Azure permissions' -ForegroundColor Magenta
        if ($AccessType -eq 'Update')
        {
            if (-not (Get-AzRoleAssignment -ObjectId $Identity.AppPrincipalId -RoleDefinitionName Owner))
            {
                New-AzRoleAssignment -PrincipalId $Identity.AppPrincipalId -RoleDefinitionName Owner | Out-Null
                Write-Host "Assigning the application '$($Identity.DisplayName)' to the role 'Owner'."
            }
            else
            {
                Write-Host "The application '$($Identity.DisplayName)' is already assigned to the role 'Owner'."
            }
        }
        Write-Host 'Done adding Azure permissions' -ForegroundColor Magenta
    }

    #------------------------------------------------------------------------------

    Write-Host 'Adding Microsoft365DSC required Graph API permissions' -ForegroundColor Magenta
    $requiredPermissions = Get-M365DSCCompiledPermissionList2 -AccessType $AccessType
    if ($AccessType -eq 'Update')
    {
        $requiredPermissions += Get-GraphPermission -PermissionName AppRoleAssignment.ReadWrite.All
    }
    $permissions = @(Get-ServicePrincipalAppPermissions -DisplayName $Identity.DisplayName)

    $permissionDifference = (Compare-Object -ReferenceObject $requiredPermissions -DifferenceObject $permissions).InputObject

    if ($permissionDifference)
    {
        Write-Host "There are $($permissionDifference.Count) permissions missing for managed identity '$($Identity.DisplayName)'"
        Write-Host "Updating permissions for managed identity '$($Identity.DisplayName)'"
        Set-ServicePrincipalAppPermissions -DisplayName $Identity.DisplayName -Permissions $requiredPermissions
    }
    else
    {
        Write-Host "Permissions for managed identity '$($Identity.DisplayName)' are up to date" -ForegroundColor Green
    }
    Write-Host 'Done adding Microsoft365DSC required Graph API permissions' -ForegroundColor Magenta

    #------------------------------------------------------------------------------

    Write-Host 'Adding identity to required roles Directory Roles' -ForegroundColor Magenta
    $globalReadersRole = Get-MgDirectoryRole -Filter "DisplayName eq 'Global Reader'"
    # If the role hasn't been activated, we need to get the role template ID to first activate the role
    if ($null -eq $globalReadersRole)
    {
        Write-Host "The role 'Global Reader' has not been activated yet. Activating the role."
        $adminRoleTemplate = Get-MgDirectoryRoleTemplate | Where-Object { $_.DisplayName -eq 'Global Reader' }
        New-MgDirectoryRole -RoleTemplateId $adminRoleTemplate.Id | Out-Null
    }

    $appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$($Identity.DisplayName)'"
    $requiredRoles = @('Global Reader')
    if ($AccessType -eq 'Update')
    {
        $requiredRoles += 'Exchange Administrator'
    }

    foreach ($requiredRole in $requiredRoles)
    {
        $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq '$requiredRole'"
        if (-not $roleDefinition)
        {
            Write-Host "Role definition '$requiredRole' not found."
            continue
        }

        if (-not (Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$($roleDefinition.Id)' and principalId eq '$($Identity.AppPrincipalId)'"))
        {
            New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId '/' | Out-Null
            Write-Host "Role assignment for service principal '$($Identity.DisplayName)' for role '$($roleDefinition.DisplayName)' created."
        }
        else
        {
            Write-Host "Role assignment for service principal '$($Identity.DisplayName)' for role '$($roleDefinition.DisplayName)' already exists."
        }
    }
    Write-Host 'Done adding identity to required roles Directory Roles' -ForegroundColor Magenta

    #------------------------------------------------------------------------------

    Write-Host 'Adding identity to required roles Exchange Roles' -ForegroundColor Magenta

    if ($AccessType -eq 'Update')
    {
        $requiredRoles = 'Organization Management',
        'Security Administrator',
        'Recipient Management',
        'Compliance Administrator',
        'Compliance Management',
        'Information Protection Admins',
        'Privacy Management Administrators',
        'Privacy Management'

        foreach ($requiredRole in $requiredRoles)
        {
            $role = Get-RoleGroup -Filter "Name -eq '$requiredRole'"
            if (-not $role)
            {
                Write-Host "Role '$requiredRole' not found."
                continue
            }

            if (Get-RoleGroupMember -Identity $role.ExchangeObjectId | Where-Object Name -EQ $Identity.AppPrincipalId)
            {
                Write-Host "The service principal '$($Identity.DisplayName)' is already a member of the role '$requiredRole'."
                continue
            }

            Write-Host "Adding service principal '$($Identity.DisplayName)' to the role '$requiredRole'."
            Add-RoleGroupMember -Identity $role.ExchangeObjectId -Member $Identity.AppPrincipalId
        }
    }

    Write-Host 'Done adding identity to required roles Exchange Roles' -ForegroundColor Magenta
}

function Remove-M365DscIdentityPermission
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [M365DscIdentity]$Identity,

        [switch]$SkipGraphApiPermissions
    )

    Write-Host 'Removing Azure permissions' -ForegroundColor Magenta
    if (Get-AzRoleAssignment -ObjectId $Identity.AppPrincipalId -RoleDefinitionName Owner)
    {
        Remove-AzRoleAssignment -PrincipalId $Identity.AppPrincipalId -RoleDefinitionName Owner | Out-Null
        Write-Host "Removing the application '$($Identity.DisplayName)' from the role 'Owner'."
    }
    else
    {
        Write-Host "The application '$($Identity.DisplayName)' is not assigned to the role 'Owner'."
    }
    Write-Host 'Done adding Azure permissions' -ForegroundColor Magenta

    #------------------------------------------------------------------------------

    if ($SkipGraphApiPermissions)
    {
        Write-Host 'Skipping removal of Microsoft365DSC required Graph API permissions' -ForegroundColor Magenta
    }
    else
    {
        Write-Host 'Removing Microsoft365DSC required Graph API permissions' -ForegroundColor Magenta
        $requiredPermissions = Get-M365DSCCompiledPermissionList2 -AccessType Update
        $requiredPermissions += Get-GraphPermission -PermissionName AppRoleAssignment.ReadWrite.All

        Write-Host "Removing permissions for managed identity '$($Identity.DisplayName)'"
        Remove-ServicePrincipalAppPermissions -DisplayName $Identity.DisplayName -Permissions $requiredPermissions

        Write-Host 'Done removing Microsoft365DSC required Graph API permissions' -ForegroundColor Magenta
    }

    #------------------------------------------------------------------------------

    Write-Host 'Removing identity to required roles Directory Roles' -ForegroundColor Magenta
    $appPrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$($Identity.DisplayName)'"
    $requiredRoles = 'Global Reader', 'Exchange Administrator'

    foreach ($requiredRole in $requiredRoles)
    {
        $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq '$requiredRole'"
        if (-not $roleDefinition)
        {
            Write-Host "Role definition '$requiredRole' not found."
            continue
        }

        if ($roleAssignment = Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$($roleDefinition.Id)' and principalId eq '$($Identity.AppPrincipalId)'")
        {
            Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $roleAssignment.Id
            Write-Host "Role assignment for service principal '$($Identity.DisplayName)' for role '$($roleDefinition.DisplayName)' removed."
        }
        else
        {
            Write-Host "Role assignment for service principal '$($Identity.DisplayName)' for role '$($roleDefinition.DisplayName)' does not exist."
        }
    }
    Write-Host 'Done removing identity to required roles Directory Roles' -ForegroundColor Magenta

    #------------------------------------------------------------------------------

    Write-Host 'Removing identity to required roles Exchange Roles' -ForegroundColor Magenta

    $requiredRoles = $requiredRoles = 'Organization Management',
    'Security Administrator',
    'Recipient Management',
    'Compliance Administrator',
    'Compliance Management',
    'Information Protection Admins',
    'Privacy Management Administrators',
    'Privacy Management'

    foreach ($requiredRole in $requiredRoles)
    {
        $role = Get-RoleGroup -Filter "Name -eq '$requiredRole'"
        if (-not $role)
        {
            Write-Host "Role '$requiredRole' not found."
            continue
        }

        if (-not (Get-RoleGroupMember -Identity $role.ExchangeObjectId | Where-Object Name -EQ $Identity.AppPrincipalId))
        {
            Write-Host "The service principal '$($Identity.DisplayName)' is not a member of the role '$requiredRole'."
            continue
        }

        Write-Host "Removing service principal '$($Identity.DisplayName)' from the role '$requiredRole'."
        Remove-RoleGroupMember -Identity $role.ExchangeObjectId -Member $Identity.AppPrincipalId -Confirm:$false
    }

    Write-Host 'Done removing identity to required roles Exchange Roles' -ForegroundColor Magenta
}
