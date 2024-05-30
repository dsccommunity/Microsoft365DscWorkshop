configuration cO365OrgSettings {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [bool]
        $AppsAndServicesIsAppAndServicesTrialEnabled,

        [Parameter()]
        [bool]
        $AppsAndServicesIsOfficeStoreEnabled,

        [Parameter()]
        [bool]
        $CortanaEnabled,

        [Parameter()]
        [bool]
        $DynamicsCustomerVoiceIsInOrgFormsPhishingScanEnabled,

        [Parameter()]
        [bool]
        $DynamicsCustomerVoiceIsRecordIdentityByDefaultEnabled,

        [Parameter()]
        [bool]
        $DynamicsCustomerVoiceIsRestrictedSurveyAccessEnabled,

        [Parameter()]
        [bool]
        $FormsIsBingImageSearchEnabled,

        [Parameter()]
        [bool]
        $FormsIsExternalSendFormEnabled,

        [Parameter()]
        [bool]
        $FormsIsExternalShareCollaborationEnabled,

        [Parameter()]
        [bool]
        $FormsIsExternalShareResultEnabled,

        [Parameter()]
        [bool]
        $FormsIsExternalShareTemplateEnabled,

        [Parameter()]
        [bool]
        $FormsIsInOrgFormsPhishingScanEnabled,

        [Parameter()]
        [bool]
        $FormsIsRecordIdentityByDefaultEnabled,

        [Parameter()]
        [bool]
        $M365WebEnableUsersToOpenFilesFrom3PStorage,

        [Parameter()]
        [bool]
        $MicrosoftVivaBriefingEmail,

        [Parameter()]
        [bool]
        $VivaInsightsWebExperience,

        [Parameter()]
        [bool]
        $VivaInsightsDigestEmail,

        [Parameter()]
        [bool]
        $VivaInsightsOutlookAddInAndInlineSuggestions,

        [Parameter()]
        [bool]
        $VivaInsightsScheduleSendSuggestions,

        [Parameter()]
        [bool]
        $PlannerAllowCalendarSharing,

        [Parameter()]
        [bool]
        $ToDoIsExternalJoinEnabled,

        [Parameter()]
        [bool]
        $ToDoIsExternalShareEnabled,

        [Parameter()]
        [bool]
        $ToDoIsPushNotificationEnabled,

        [Parameter()]
        [bool]
        $AdminCenterReportDisplayConcealedNames,

        [Parameter()]
        [ValidateSet('current', 'monthlyEnterprise', 'semiAnnual')]
        [string]
        $InstallationOptionsUpdateChannel,

        [Parameter()]
        [ValidateSet('isVisioEnabled', 'isSkypeForBusinessEnabled', 'isProjectEnabled', 'isMicrosoft365AppsEnabled')]
        [string[]]
        $InstallationOptionsAppsForWindows,

        [Parameter()]
        [ValidateSet('isSkypeForBusinessEnabled', 'isMicrosoft365AppsEnabled')]
        [string[]]
        $InstallationOptionsAppsForMac,

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
        $ManagedIdentity,

        [Parameter()]
        [string[]]
        $AccessTokens
)

<#
O365OrgSettings [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [AccessTokens = [string[]]]
    [AdminCenterReportDisplayConcealedNames = [bool]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [AppsAndServicesIsAppAndServicesTrialEnabled = [bool]]
    [AppsAndServicesIsOfficeStoreEnabled = [bool]]
    [CertificateThumbprint = [string]]
    [CortanaEnabled = [bool]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [DynamicsCustomerVoiceIsInOrgFormsPhishingScanEnabled = [bool]]
    [DynamicsCustomerVoiceIsRecordIdentityByDefaultEnabled = [bool]]
    [DynamicsCustomerVoiceIsRestrictedSurveyAccessEnabled = [bool]]
    [FormsIsBingImageSearchEnabled = [bool]]
    [FormsIsExternalSendFormEnabled = [bool]]
    [FormsIsExternalShareCollaborationEnabled = [bool]]
    [FormsIsExternalShareResultEnabled = [bool]]
    [FormsIsExternalShareTemplateEnabled = [bool]]
    [FormsIsInOrgFormsPhishingScanEnabled = [bool]]
    [FormsIsRecordIdentityByDefaultEnabled = [bool]]
    [InstallationOptionsAppsForMac = [string[]]{ isMicrosoft365AppsEnabled | isSkypeForBusinessEnabled }]
    [InstallationOptionsAppsForWindows = [string[]]{ isMicrosoft365AppsEnabled | isProjectEnabled | isSkypeForBusinessEnabled | isVisioEnabled }]
    [InstallationOptionsUpdateChannel = [string]{ current | monthlyEnterprise | semiAnnual }]
    [M365WebEnableUsersToOpenFilesFrom3PStorage = [bool]]
    [ManagedIdentity = [bool]]
    [MicrosoftVivaBriefingEmail = [bool]]
    [PlannerAllowCalendarSharing = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
    [ToDoIsExternalJoinEnabled = [bool]]
    [ToDoIsExternalShareEnabled = [bool]]
    [ToDoIsPushNotificationEnabled = [bool]]
    [VivaInsightsDigestEmail = [bool]]
    [VivaInsightsOutlookAddInAndInlineSuggestions = [bool]]
    [VivaInsightsScheduleSendSuggestions = [bool]]
    [VivaInsightsWebExperience = [bool]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'O365OrgSettings'

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

