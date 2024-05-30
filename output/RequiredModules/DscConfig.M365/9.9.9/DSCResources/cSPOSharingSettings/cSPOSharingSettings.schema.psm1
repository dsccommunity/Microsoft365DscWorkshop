configuration cSPOSharingSettings {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [ValidateSet('ExistingExternalUserSharingOnly', 'ExternalUserAndGuestSharing', 'Disabled', 'ExternalUserSharingOnly')]
        [string]
        $SharingCapability,

        [Parameter()]
        [ValidateSet('ExistingExternalUserSharingOnly', 'ExternalUserAndGuestSharing', 'Disabled', 'ExternalUserSharingOnly')]
        [string]
        $MySiteSharingCapability,

        [Parameter()]
        [bool]
        $ShowEveryoneClaim,

        [Parameter()]
        [bool]
        $ShowAllUsersClaim,

        [Parameter()]
        [bool]
        $ShowEveryoneExceptExternalUsersClaim,

        [Parameter()]
        [bool]
        $ProvisionSharedWithEveryoneFolder,

        [Parameter()]
        [bool]
        $EnableGuestSignInAcceleration,

        [Parameter()]
        [bool]
        $BccExternalSharingInvitations,

        [Parameter()]
        [string]
        $BccExternalSharingInvitationsList,

        [Parameter()]
        [System.UInt32]
        $RequireAnonymousLinksExpireInDays,

        [Parameter()]
        [string[]]
        $SharingAllowedDomainList,

        [Parameter()]
        [string[]]
        $SharingBlockedDomainList,

        [Parameter()]
        [ValidateSet('None', 'AllowList', 'BlockList')]
        [string]
        $SharingDomainRestrictionMode,

        [Parameter()]
        [ValidateSet('None', 'Direct', 'Internal', 'AnonymousAccess')]
        [string]
        $DefaultSharingLinkType,

        [Parameter()]
        [bool]
        $PreventExternalUsersFromResharing,

        [Parameter()]
        [bool]
        $ShowPeoplePickerSuggestionsForGuestUsers,

        [Parameter()]
        [ValidateSet('View', 'Edit')]
        [string]
        $FileAnonymousLinkType,

        [Parameter()]
        [ValidateSet('View', 'Edit')]
        [string]
        $FolderAnonymousLinkType,

        [Parameter()]
        [bool]
        $NotifyOwnersWhenItemsReshared,

        [Parameter()]
        [ValidateSet('None', 'View', 'Edit')]
        [string]
        $DefaultLinkPermission,

        [Parameter()]
        [bool]
        $RequireAcceptingAccountMatchInvitedAccount,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure,

        [Parameter()]
        [PSCredential]
        $Credential,

        [Parameter()]
        [string]
        $ApplicationId,

        [Parameter()]
        [PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [string]
        $TenantId,

        [Parameter()]
        [PSCredential]
        $CertificatePassword,

        [Parameter()]
        [string]
        $CertificatePath,

        [Parameter()]
        [string]
        $CertificateThumbprint,

        [Parameter()]
        [bool]
        $ManagedIdentity,

        [Parameter()]
        [bool]
        $ExternalUserExpirationRequired,

        [Parameter()]
        [System.UInt32]
        $ExternalUserExpireInDays,

        [Parameter()]
        [string[]]
        $AccessTokens
)

<#
SPOSharingSettings [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [BccExternalSharingInvitations = [bool]]
    [BccExternalSharingInvitationsList = [string]]
    [CertificatePassword = [PSCredential]]
    [CertificatePath = [string]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DefaultLinkPermission = [string]{ Edit | None | View }]
    [DefaultSharingLinkType = [string]{ AnonymousAccess | Direct | Internal | None }]
    [DependsOn = [string[]]]
    [EnableGuestSignInAcceleration = [bool]]
    [Ensure = [string]{ Absent | Present }]
    [ExternalUserExpirationRequired = [bool]]
    [ExternalUserExpireInDays = [UInt32]]
    [FileAnonymousLinkType = [string]{ Edit | View }]
    [FolderAnonymousLinkType = [string]{ Edit | View }]
    [ManagedIdentity = [bool]]
    [MySiteSharingCapability = [string]{ Disabled | ExistingExternalUserSharingOnly | ExternalUserAndGuestSharing | ExternalUserSharingOnly }]
    [NotifyOwnersWhenItemsReshared = [bool]]
    [PreventExternalUsersFromResharing = [bool]]
    [ProvisionSharedWithEveryoneFolder = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [RequireAcceptingAccountMatchInvitedAccount = [bool]]
    [RequireAnonymousLinksExpireInDays = [UInt32]]
    [SharingAllowedDomainList = [string[]]]
    [SharingBlockedDomainList = [string[]]]
    [SharingCapability = [string]{ Disabled | ExistingExternalUserSharingOnly | ExternalUserAndGuestSharing | ExternalUserSharingOnly }]
    [SharingDomainRestrictionMode = [string]{ AllowList | BlockList | None }]
    [ShowAllUsersClaim = [bool]]
    [ShowEveryoneClaim = [bool]]
    [ShowEveryoneExceptExternalUsersClaim = [bool]]
    [ShowPeoplePickerSuggestionsForGuestUsers = [bool]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'SPOSharingSettings'

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

