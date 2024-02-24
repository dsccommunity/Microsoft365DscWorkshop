configuration cAADGroupsSettings {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [string]
        $IsSingleInstance,

        [Parameter()]
        [bool]
        $EnableGroupCreation,

        [Parameter()]
        [bool]
        $EnableMIPLabels,

        [Parameter()]
        [bool]
        $AllowGuestsToBeGroupOwner,

        [Parameter()]
        [bool]
        $AllowGuestsToAccessGroups,

        [Parameter()]
        [string]
        $GuestUsageGuidelinesUrl,

        [Parameter()]
        [string]
        $GroupCreationAllowedGroupName,

        [Parameter()]
        [bool]
        $AllowToAddGuests,

        [Parameter()]
        [string]
        $UsageGuidelinesUrl,

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
AADGroupsSettings [String] #ResourceName
{
    IsSingleInstance = [string]{ Yes }
    [AllowGuestsToAccessGroups = [bool]]
    [AllowGuestsToBeGroupOwner = [bool]]
    [AllowToAddGuests = [bool]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [EnableGroupCreation = [bool]]
    [EnableMIPLabels = [bool]]
    [Ensure = [string]{ Absent | Present }]
    [GroupCreationAllowedGroupName = [string]]
    [GuestUsageGuidelinesUrl = [string]]
    [ManagedIdentity = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
    [UsageGuidelinesUrl = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADGroupsSettings'

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

