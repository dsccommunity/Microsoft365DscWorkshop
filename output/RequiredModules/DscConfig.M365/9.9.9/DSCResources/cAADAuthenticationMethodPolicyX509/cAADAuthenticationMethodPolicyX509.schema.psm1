configuration cAADAuthenticationMethodPolicyX509 {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADAuthenticationMethodPolicyX509 [String] #ResourceName
{
    Id = [string]
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [AuthenticationModeConfiguration = [MSFT_MicrosoftGraphx509CertificateAuthenticationModeConfiguration]]
    [CertificateThumbprint = [string]]
    [CertificateUserBindings = [MSFT_MicrosoftGraphx509CertificateUserBinding[]]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [ExcludeTargets = [MSFT_AADAuthenticationMethodPolicyX509ExcludeTarget[]]]
    [IncludeTargets = [MSFT_AADAuthenticationMethodPolicyX509IncludeTarget[]]]
    [ManagedIdentity = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [State = [string]{ disabled | enabled }]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADAuthenticationMethodPolicyX509'

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

