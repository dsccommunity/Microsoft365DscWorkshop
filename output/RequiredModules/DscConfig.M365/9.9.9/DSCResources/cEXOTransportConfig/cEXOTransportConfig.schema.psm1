configuration cEXOTransportConfig {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [bool]
        $AddressBookPolicyRoutingEnabled,

        [Parameter()]
        [bool]
        $AllowLegacyTLSClients,

        [Parameter()]
        [bool]
        $ClearCategories,

        [Parameter()]
        [bool]
        $ConvertDisclaimerWrapperToEml,

        [Parameter()]
        [string]
        $DSNConversionMode,

        [Parameter()]
        [bool]
        $ExternalDelayDsnEnabled,

        [Parameter()]
        [string]
        $ExternalDsnDefaultLanguage,

        [Parameter()]
        [bool]
        $ExternalDsnLanguageDetectionEnabled,

        [Parameter()]
        [string]
        $ExternalDsnReportingAuthority,

        [Parameter()]
        [bool]
        $ExternalDsnSendHtml,

        [Parameter()]
        [string]
        $ExternalPostmasterAddress,

        [Parameter()]
        [string]
        $HeaderPromotionModeSetting,

        [Parameter()]
        [bool]
        $InternalDelayDsnEnabled,

        [Parameter()]
        [string]
        $InternalDsnDefaultLanguage,

        [Parameter()]
        [bool]
        $InternalDsnLanguageDetectionEnabled,

        [Parameter()]
        [string]
        $InternalDsnReportingAuthority,

        [Parameter()]
        [bool]
        $InternalDsnSendHtml,

        [Parameter()]
        [int]
        $JournalMessageExpirationDays,

        [Parameter()]
        [string]
        $JournalingReportNdrTo,

        [Parameter()]
        [string]
        $MaxRecipientEnvelopeLimit,

        [Parameter()]
        [int]
        $ReplyAllStormBlockDurationHours,

        [Parameter()]
        [int]
        $ReplyAllStormDetectionMinimumRecipients,

        [Parameter()]
        [int]
        $ReplyAllStormDetectionMinimumReplies,

        [Parameter()]
        [bool]
        $ReplyAllStormProtectionEnabled,

        [Parameter()]
        [bool]
        $Rfc2231EncodingEnabled,

        [Parameter()]
        [bool]
        $SmtpClientAuthenticationDisabled,

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
        [string]
        $CertificateThumbprint,

        [Parameter()]
        [PSCredential]
        $CertificatePassword,

        [Parameter()]
        [string]
        $CertificatePath,

        [Parameter()]
        [bool]
        $ManagedIdentity,

        [Parameter()]
        [string[]]
        $AccessTokens
)

<#
EXOTransportConfig [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [AccessTokens = [string[]]]
    [AddressBookPolicyRoutingEnabled = [bool]]
    [AllowLegacyTLSClients = [bool]]
    [ApplicationId = [string]]
    [CertificatePassword = [PSCredential]]
    [CertificatePath = [string]]
    [CertificateThumbprint = [string]]
    [ClearCategories = [bool]]
    [ConvertDisclaimerWrapperToEml = [bool]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [DSNConversionMode = [string]]
    [ExternalDelayDsnEnabled = [bool]]
    [ExternalDsnDefaultLanguage = [string]]
    [ExternalDsnLanguageDetectionEnabled = [bool]]
    [ExternalDsnReportingAuthority = [string]]
    [ExternalDsnSendHtml = [bool]]
    [ExternalPostmasterAddress = [string]]
    [HeaderPromotionModeSetting = [string]]
    [InternalDelayDsnEnabled = [bool]]
    [InternalDsnDefaultLanguage = [string]]
    [InternalDsnLanguageDetectionEnabled = [bool]]
    [InternalDsnReportingAuthority = [string]]
    [InternalDsnSendHtml = [bool]]
    [JournalingReportNdrTo = [string]]
    [JournalMessageExpirationDays = [Int32]]
    [ManagedIdentity = [bool]]
    [MaxRecipientEnvelopeLimit = [string]]
    [PsDscRunAsCredential = [PSCredential]]
    [ReplyAllStormBlockDurationHours = [Int32]]
    [ReplyAllStormDetectionMinimumRecipients = [Int32]]
    [ReplyAllStormDetectionMinimumReplies = [Int32]]
    [ReplyAllStormProtectionEnabled = [bool]]
    [Rfc2231EncodingEnabled = [bool]]
    [SmtpClientAuthenticationDisabled = [bool]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'EXOTransportConfig'

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

