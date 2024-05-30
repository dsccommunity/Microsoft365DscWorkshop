configuration cEXORemoteDomain {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
EXORemoteDomain [String] #ResourceName
{
    Identity = [string]
    [AccessTokens = [string[]]]
    [AllowedOOFType = [string]{ External | ExternalLegacy | InternalLegacy | None }]
    [ApplicationId = [string]]
    [AutoForwardEnabled = [bool]]
    [AutoReplyEnabled = [bool]]
    [ByteEncoderTypeFor7BitCharsets = [string]{ Undefined | Use7Bit | UseBase64 | UseBase64Html7BitTextPlain | UseBase64HtmlDetectTextPlain | UseQP | UseQPHtml7BitTextPlain | UseQPHtmlDetectTextPlain }]
    [CertificatePassword = [PSCredential]]
    [CertificatePath = [string]]
    [CertificateThumbprint = [string]]
    [CharacterSet = [string]]
    [ContentType = [string]{ MimeHtml | MimeHtmlText | MimeText }]
    [Credential = [PSCredential]]
    [DeliveryReportEnabled = [bool]]
    [DependsOn = [string[]]]
    [DisplaySenderName = [bool]]
    [DomainName = [string]]
    [Ensure = [string]{ Absent | Present }]
    [IsInternal = [bool]]
    [LineWrapSize = [string]]
    [ManagedIdentity = [bool]]
    [MeetingForwardNotificationEnabled = [bool]]
    [Name = [string]]
    [NDREnabled = [bool]]
    [NonMimeCharacterSet = [string]]
    [PreferredInternetCodePageForShiftJis = [string]{ 50220 | 50221 | 50222 | Undefined }]
    [PsDscRunAsCredential = [PSCredential]]
    [RequiredCharsetCoverage = [Int32]]
    [TargetDeliveryDomain = [bool]]
    [TenantId = [string]]
    [TNEFEnabled = [bool]]
    [TrustedMailInboundEnabled = [bool]]
    [TrustedMailOutboundEnabled = [bool]]
    [UseSimpleDisplayName = [bool]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'EXORemoteDomain'

    $param = $PSBoundParameters
    $param.Remove("InstanceName")

    $dscParameterKeys = 'Identity' -split ', '

        foreach ($item in $Items)
        {
            if (-not $item.ContainsKey('Ensure'))
            {
                $item.Ensure = 'Present'
            }
            $keyValues = foreach ($key in $dscParameterKeys)
        {
            $item.$key
        }
        $executionName = $keyValues -join '_'
        $executionName = $executionName -replace "[\s()\\:*-+/{}```"']", '_'
        (Get-DscSplattedResource -ResourceName $dscResourceName -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
    }
}

