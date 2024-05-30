configuration cAADGroup {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADGroup [String] #ResourceName
{
    DisplayName = [string]
    MailEnabled = [bool]
    MailNickname = [string]
    SecurityEnabled = [bool]
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [AssignedLicenses = [MSFT_AADGroupLicense[]]]
    [AssignedToRole = [string[]]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Description = [string]]
    [Ensure = [string]{ Absent | Present }]
    [GroupTypes = [string[]]]
    [Id = [string]]
    [IsAssignableToRole = [bool]]
    [ManagedIdentity = [bool]]
    [MemberOf = [string[]]]
    [Members = [string[]]]
    [MembershipRule = [string]]
    [MembershipRuleProcessingState = [string]{ On | Paused }]
    [Owners = [string[]]]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
    [Visibility = [string]{ HiddenMembership | Private | Public }]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADGroup'

    $param = $PSBoundParameters
    $param.Remove("InstanceName")

    $dscParameterKeys = 'DisplayName, MailNickname' -split ', '

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

