configuration cAADTenantDetails {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [string[]]
        $MarketingNotificationEmails,

        [Parameter()]
        [string[]]
        $SecurityComplianceNotificationMails,

        [Parameter()]
        [string[]]
        $SecurityComplianceNotificationPhones,

        [Parameter()]
        [string[]]
        $TechnicalNotificationMails,

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
AADTenantDetails [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [ManagedIdentity = [bool]]
    [MarketingNotificationEmails = [string[]]]
    [PsDscRunAsCredential = [PSCredential]]
    [SecurityComplianceNotificationMails = [string[]]]
    [SecurityComplianceNotificationPhones = [string[]]]
    [TechnicalNotificationMails = [string[]]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADTenantDetails'

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

