configuration cEXOAcceptedDomain {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
EXOAcceptedDomain [String] #ResourceName
{
    Identity = [string]
    [ApplicationId = [string]]
    [CertificatePassword = [PSCredential]]
    [CertificatePath = [string]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [DomainType = [string]{ Authoritative | InternalRelay }]
    [Ensure = [string]{ Absent | Present }]
    [ManagedIdentity = [bool]]
    [MatchSubDomains = [bool]]
    [OutboundOnly = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'EXOAcceptedDomain'

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

