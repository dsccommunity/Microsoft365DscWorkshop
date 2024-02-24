configuration cAADSecurityDefaults {
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
        $IsEnabled,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [string]
        $Ensure,

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
        $ApplicationSecret,

        [Parameter()]
        [PSCredential]
        $Credential,

        [Parameter()]
        [bool]
        $ManagedIdentity
)

<#
AADSecurityDefaults [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Description = [string]]
    [DisplayName = [string]]
    [Ensure = [string]{ Absent | Present }]
    [IsEnabled = [bool]]
    [ManagedIdentity = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADSecurityDefaults'

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

