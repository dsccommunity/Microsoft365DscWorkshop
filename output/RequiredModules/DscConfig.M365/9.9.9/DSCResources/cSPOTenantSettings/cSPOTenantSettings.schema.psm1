configuration cSPOTenantSettings {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [System.UInt32]
        $MinCompatibilityLevel,

        [Parameter()]
        [System.UInt32]
        $MaxCompatibilityLevel,

        [Parameter()]
        [bool]
        $SearchResolveExactEmailOrUPN,

        [Parameter()]
        [bool]
        $OfficeClientADALDisabled,

        [Parameter()]
        [bool]
        $LegacyAuthProtocolsEnabled,

        [Parameter()]
        [string]
        $SignInAccelerationDomain,

        [Parameter()]
        [bool]
        $UsePersistentCookiesForExplorerView,

        [Parameter()]
        [bool]
        $UserVoiceForFeedbackEnabled,

        [Parameter()]
        [bool]
        $PublicCdnEnabled,

        [Parameter()]
        [string]
        $PublicCdnAllowedFileTypes,

        [Parameter()]
        [bool]
        $UseFindPeopleInPeoplePicker,

        [Parameter()]
        [bool]
        $NotificationsInSharePointEnabled,

        [Parameter()]
        [bool]
        $OwnerAnonymousNotification,

        [Parameter()]
        [bool]
        $ApplyAppEnforcedRestrictionsToAdHocRecipients,

        [Parameter()]
        [bool]
        $FilePickerExternalImageSearchEnabled,

        [Parameter()]
        [bool]
        $HideDefaultThemes,

        [Parameter()]
        [bool]
        $HideSyncButtonOnTeamSite,

        [Parameter()]
        [ValidateSet('AllowExternalSharing', 'BlockExternalSharing')]
        [string]
        $MarkNewFilesSensitiveByDefault,

        [Parameter()]
        [string[]]
        $DisabledWebPartIds,

        [Parameter()]
        [bool]
        $SocialBarOnSitePagesDisabled,

        [Parameter()]
        [bool]
        $CommentsOnSitePagesDisabled,

        [Parameter()]
        [bool]
        $EnableAIPIntegration,

        [Parameter()]
        [string]
        $TenantDefaultTimezone,

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
        [string[]]
        $AccessTokens
)

<#
SPOTenantSettings [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [ApplyAppEnforcedRestrictionsToAdHocRecipients = [bool]]
    [CertificatePassword = [PSCredential]]
    [CertificatePath = [string]]
    [CertificateThumbprint = [string]]
    [CommentsOnSitePagesDisabled = [bool]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [DisabledWebPartIds = [string[]]]
    [EnableAIPIntegration = [bool]]
    [Ensure = [string]{ Absent | Present }]
    [FilePickerExternalImageSearchEnabled = [bool]]
    [HideDefaultThemes = [bool]]
    [HideSyncButtonOnTeamSite = [bool]]
    [LegacyAuthProtocolsEnabled = [bool]]
    [ManagedIdentity = [bool]]
    [MarkNewFilesSensitiveByDefault = [string]{ AllowExternalSharing | BlockExternalSharing }]
    [MaxCompatibilityLevel = [UInt32]]
    [MinCompatibilityLevel = [UInt32]]
    [NotificationsInSharePointEnabled = [bool]]
    [OfficeClientADALDisabled = [bool]]
    [OwnerAnonymousNotification = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [PublicCdnAllowedFileTypes = [string]]
    [PublicCdnEnabled = [bool]]
    [SearchResolveExactEmailOrUPN = [bool]]
    [SignInAccelerationDomain = [string]]
    [SocialBarOnSitePagesDisabled = [bool]]
    [TenantDefaultTimezone = [string]]
    [TenantId = [string]]
    [UseFindPeopleInPeoplePicker = [bool]]
    [UsePersistentCookiesForExplorerView = [bool]]
    [UserVoiceForFeedbackEnabled = [bool]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'SPOTenantSettings'

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

