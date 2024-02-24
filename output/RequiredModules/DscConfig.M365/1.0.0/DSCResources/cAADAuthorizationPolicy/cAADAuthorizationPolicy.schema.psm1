configuration cAADAuthorizationPolicy {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [string]
        $DisplayName,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [bool]
        $AllowedToSignUpEmailBasedSubscriptions,

        [Parameter()]
        [bool]
        $AllowedToUseSSPR,

        [Parameter()]
        [bool]
        $AllowEmailVerifiedUsersToJoinOrganization,

        [Parameter()]
        [ValidateSet('None', 'AdminsAndGuestInviters', 'AdminsGuestInvitersAndAllMembers', 'Everyone')]
        [string]
        $AllowInvitesFrom,

        [Parameter()]
        [bool]
        $BlockMsolPowershell,

        [Parameter()]
        [bool]
        $DefaultUserRoleAllowedToCreateApps,

        [Parameter()]
        [bool]
        $DefaultUserRoleAllowedToCreateSecurityGroups,

        [Parameter()]
        [bool]
        $DefaultUserRoleAllowedToReadBitlockerKeysForOwnedDevice,

        [Parameter()]
        [bool]
        $DefaultUserRoleAllowedToCreateTenants,

        [Parameter()]
        [bool]
        $DefaultUserRoleAllowedToReadOtherUsers,

        [Parameter()]
        [ValidateSet('Guest', 'RestrictedGuest', 'User')]
        [string]
        $GuestUserRole,

        [Parameter()]
        [string[]]
        $PermissionGrantPolicyIdsAssignedToDefaultUserRole,

        [Parameter()]
        [ValidateSet('Present')]
        [string]
        $Ensure,

        [Parameter()]
        [PSCredential]
        $Credential,

        [Parameter()]
        [string]
        $ApplicationId,

        [Parameter()]
        [string]
        $TenantId,

        [Parameter()]
        [PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [string]
        $CertificateThumbprint,

        [Parameter()]
        [bool]
        $ManagedIdentity
)

<#
AADAuthorizationPolicy [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [AllowedToSignUpEmailBasedSubscriptions = [bool]]
    [AllowedToUseSSPR = [bool]]
    [AllowEmailVerifiedUsersToJoinOrganization = [bool]]
    [AllowInvitesFrom = [string]{ AdminsAndGuestInviters | AdminsGuestInvitersAndAllMembers | Everyone | None }]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [BlockMsolPowershell = [bool]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DefaultUserRoleAllowedToCreateApps = [bool]]
    [DefaultUserRoleAllowedToCreateSecurityGroups = [bool]]
    [DefaultUserRoleAllowedToCreateTenants = [bool]]
    [DefaultUserRoleAllowedToReadBitlockerKeysForOwnedDevice = [bool]]
    [DefaultUserRoleAllowedToReadOtherUsers = [bool]]
    [DependsOn = [string[]]]
    [Description = [string]]
    [DisplayName = [string]]
    [Ensure = [string]{ Present }]
    [GuestUserRole = [string]{ Guest | RestrictedGuest | User }]
    [ManagedIdentity = [bool]]
    [PermissionGrantPolicyIdsAssignedToDefaultUserRole = [string[]]]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADAuthorizationPolicy'

    $param = $PSBoundParameters
    $param.Remove("InstanceName")

    $dscParameterKeys = 'IsSingleInstance' -split ', '

    $keyValues = foreach ($key in $dscParameterKeys)
    {
        $param.$key
    }
    $executionName = $keyValues -join '_'
    $executionName = $executionName -replace "[\s()\\:*-+/{}```"']", '_'

    (Get-DscSplattedResource -ResourceName $dscResourceName -ExecutionName $executionName -Properties $param -NoInvoke).Invoke($param)

}

