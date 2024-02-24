configuration cAADGroupsNamingPolicy {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [string]
        $PrefixSuffixNamingRequirement,

        [Parameter()]
        [string[]]
        $CustomBlockedWordsList,

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
AADGroupsNamingPolicy [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [CustomBlockedWordsList = [string[]]]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [ManagedIdentity = [bool]]
    [PrefixSuffixNamingRequirement = [string]]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADGroupsNamingPolicy'

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

