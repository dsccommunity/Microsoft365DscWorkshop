configuration cSPOAccessControlSettings {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [bool]
        $DisplayStartASiteOption,

        [Parameter()]
        [string]
        $StartASiteFormUrl,

        [Parameter()]
        [bool]
        $IPAddressEnforcement,

        [Parameter()]
        [string]
        $IPAddressAllowList,

        [Parameter()]
        [System.UInt32]
        $IPAddressWACTokenLifetime,

        [Parameter()]
        [bool]
        $DisallowInfectedFileDownload,

        [Parameter()]
        [bool]
        $ExternalServicesEnabled,

        [Parameter()]
        [bool]
        $EmailAttestationRequired,

        [Parameter()]
        [System.UInt32]
        $EmailAttestationReAuthDays,

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
        [ValidateSet('AllowFullAccess', 'AllowLimitedAccess', 'BlockAccess', 'ProtectionLevel')]
        [string]
        $ConditionalAccessPolicy,

        [Parameter()]
        [string[]]
        $AccessTokens
)

<#
SPOAccessControlSettings [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificatePassword = [PSCredential]]
    [CertificatePath = [string]]
    [CertificateThumbprint = [string]]
    [ConditionalAccessPolicy = [string]{ AllowFullAccess | AllowLimitedAccess | BlockAccess | ProtectionLevel }]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [DisallowInfectedFileDownload = [bool]]
    [DisplayStartASiteOption = [bool]]
    [EmailAttestationReAuthDays = [UInt32]]
    [EmailAttestationRequired = [bool]]
    [Ensure = [string]{ Absent | Present }]
    [ExternalServicesEnabled = [bool]]
    [IPAddressAllowList = [string]]
    [IPAddressEnforcement = [bool]]
    [IPAddressWACTokenLifetime = [UInt32]]
    [ManagedIdentity = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [StartASiteFormUrl = [string]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'SPOAccessControlSettings'

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

