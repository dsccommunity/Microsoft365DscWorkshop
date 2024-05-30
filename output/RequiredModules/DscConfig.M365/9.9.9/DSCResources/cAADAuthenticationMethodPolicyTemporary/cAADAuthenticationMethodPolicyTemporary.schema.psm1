configuration cAADAuthenticationMethodPolicyTemporary {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADAuthenticationMethodPolicyTemporary [String] #ResourceName
{
    Id = [string]
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DefaultLength = [UInt32]]
    [DefaultLifetimeInMinutes = [UInt32]]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [ExcludeTargets = [MSFT_AADAuthenticationMethodPolicyTemporaryExcludeTarget[]]]
    [IncludeTargets = [MSFT_AADAuthenticationMethodPolicyTemporaryIncludeTarget[]]]
    [IsUsableOnce = [bool]]
    [ManagedIdentity = [bool]]
    [MaximumLifetimeInMinutes = [UInt32]]
    [MinimumLifetimeInMinutes = [UInt32]]
    [PsDscRunAsCredential = [PSCredential]]
    [State = [string]{ disabled | enabled }]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADAuthenticationMethodPolicyTemporary'

    $param = $PSBoundParameters
    $param.Remove("InstanceName")

    $dscParameterKeys = 'Id' -split ', '

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

