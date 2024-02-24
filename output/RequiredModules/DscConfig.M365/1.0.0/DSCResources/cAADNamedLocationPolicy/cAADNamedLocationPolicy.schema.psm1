configuration cAADNamedLocationPolicy {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADNamedLocationPolicy [String] #ResourceName
{
    DisplayName = [string]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [CountriesAndRegions = [string[]]]
    [CountryLookupMethod = [string]{ authenticatorAppGps | clientIpAddress }]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [Id = [string]]
    [IncludeUnknownCountriesAndRegions = [bool]]
    [IpRanges = [string[]]]
    [IsTrusted = [bool]]
    [ManagedIdentity = [bool]]
    [OdataType = [string]{ #microsoft.graph.compliantNetworkNamedLocation | #microsoft.graph.countryNamedLocation | #microsoft.graph.ipNamedLocation }]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADNamedLocationPolicy'

    $param = $PSBoundParameters
    $param.Remove("InstanceName")

    $dscParameterKeys = 'DisplayName' -split ', '

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

