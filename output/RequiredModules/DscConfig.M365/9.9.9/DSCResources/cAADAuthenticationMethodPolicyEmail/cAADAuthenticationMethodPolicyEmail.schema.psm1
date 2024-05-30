configuration cAADAuthenticationMethodPolicyEmail {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADAuthenticationMethodPolicyEmail [String] #ResourceName
{
    Id = [string]
    [AccessTokens = [string[]]]
    [AllowExternalIdToUseEmailOtp = [string]{ default | disabled | enabled | unknownFutureValue }]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [ExcludeTargets = [MSFT_AADAuthenticationMethodPolicyEmailExcludeTarget[]]]
    [IncludeTargets = [MSFT_AADAuthenticationMethodPolicyEmailIncludeTarget[]]]
    [ManagedIdentity = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [State = [string]{ disabled | enabled }]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADAuthenticationMethodPolicyEmail'

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

