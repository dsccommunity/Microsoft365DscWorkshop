configuration cAADApplication {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADApplication [String] #ResourceName
{
    DisplayName = [string]
    [AppId = [string]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [AvailableToOtherTenants = [bool]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Description = [string]]
    [Ensure = [string]{ Absent | Present }]
    [GroupMembershipClaims = [string]]
    [Homepage = [string]]
    [IdentifierUris = [string[]]]
    [IsFallbackPublicClient = [bool]]
    [KnownClientApplications = [string[]]]
    [LogoutURL = [string]]
    [ManagedIdentity = [bool]]
    [ObjectId = [string]]
    [Owners = [string[]]]
    [Permissions = [MSFT_AADApplicationPermission[]]]
    [PsDscRunAsCredential = [PSCredential]]
    [PublicClient = [bool]]
    [ReplyURLs = [string[]]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADApplication'

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

