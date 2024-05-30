configuration cAADServicePrincipal {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADServicePrincipal [String] #ResourceName
{
    AppId = [string]
    [AccessTokens = [string[]]]
    [AccountEnabled = [bool]]
    [AlternativeNames = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [AppRoleAssignedTo = [MSFT_AADServicePrincipalRoleAssignment[]]]
    [AppRoleAssignmentRequired = [bool]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [DisplayName = [string]]
    [Ensure = [string]{ Absent | Present }]
    [ErrorUrl = [string]]
    [Homepage = [string]]
    [LogoutUrl = [string]]
    [ManagedIdentity = [bool]]
    [ObjectID = [string]]
    [PsDscRunAsCredential = [PSCredential]]
    [PublisherName = [string]]
    [ReplyUrls = [string[]]]
    [SamlMetadataUrl = [string]]
    [ServicePrincipalNames = [string[]]]
    [ServicePrincipalType = [string]]
    [Tags = [string[]]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADServicePrincipal'

    $param = $PSBoundParameters
    $param.Remove("InstanceName")

    $dscParameterKeys = 'AppId' -split ', '

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

