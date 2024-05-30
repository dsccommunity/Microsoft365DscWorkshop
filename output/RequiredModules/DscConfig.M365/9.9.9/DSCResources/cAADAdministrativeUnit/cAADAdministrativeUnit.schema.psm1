configuration cAADAdministrativeUnit {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADAdministrativeUnit [String] #ResourceName
{
    DisplayName = [string]
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Description = [string]]
    [Ensure = [string]{ Absent | Present }]
    [Id = [string]]
    [ManagedIdentity = [bool]]
    [Members = [MSFT_MicrosoftGraphMember[]]]
    [MembershipRule = [string]]
    [MembershipRuleProcessingState = [string]]
    [MembershipType = [string]]
    [PsDscRunAsCredential = [PSCredential]]
    [ScopedRoleMembers = [MSFT_MicrosoftGraphScopedRoleMembership[]]]
    [TenantId = [string]]
    [Visibility = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADAdministrativeUnit'

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

