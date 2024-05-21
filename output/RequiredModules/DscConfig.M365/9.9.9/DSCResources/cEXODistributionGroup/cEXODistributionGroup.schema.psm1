configuration cEXODistributionGroup {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
EXODistributionGroup [String] #ResourceName
{
    Identity = [string]
    Name = [string]
    [AcceptMessagesOnlyFrom = [string[]]]
    [AcceptMessagesOnlyFromDLMembers = [string[]]]
    [AcceptMessagesOnlyFromSendersOrMembers = [string[]]]
    [Alias = [string]]
    [ApplicationId = [string]]
    [BccBlocked = [bool]]
    [BypassNestedModerationEnabled = [bool]]
    [CertificatePassword = [PSCredential]]
    [CertificatePath = [string]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [CustomAttribute1 = [string]]
    [CustomAttribute10 = [string]]
    [CustomAttribute11 = [string]]
    [CustomAttribute12 = [string]]
    [CustomAttribute13 = [string]]
    [CustomAttribute14 = [string]]
    [CustomAttribute15 = [string]]
    [CustomAttribute2 = [string]]
    [CustomAttribute3 = [string]]
    [CustomAttribute4 = [string]]
    [CustomAttribute5 = [string]]
    [CustomAttribute6 = [string]]
    [CustomAttribute7 = [string]]
    [CustomAttribute8 = [string]]
    [CustomAttribute9 = [string]]
    [DependsOn = [string[]]]
    [Description = [string]]
    [DisplayName = [string]]
    [EmailAddresses = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [GrantSendOnBehalfTo = [string[]]]
    [HiddenFromAddressListsEnabled = [bool]]
    [HiddenGroupMembershipEnabled = [bool]]
    [ManagedBy = [string[]]]
    [ManagedIdentity = [bool]]
    [MemberDepartRestriction = [string]{ Closed | Open }]
    [MemberJoinRestriction = [string]{ ApprovalRequired | Closed | Open }]
    [Members = [string[]]]
    [ModeratedBy = [string[]]]
    [ModerationEnabled = [bool]]
    [Notes = [string]]
    [OrganizationalUnit = [string]]
    [PrimarySmtpAddress = [string]]
    [PsDscRunAsCredential = [PSCredential]]
    [RequireSenderAuthenticationEnabled = [bool]]
    [RoomList = [bool]]
    [SendModerationNotifications = [string]{ Always | Internal | Never }]
    [SendOofMessageToOriginatorEnabled = [bool]]
    [TenantId = [string]]
    [Type = [string]{ Distribution | Security }]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'EXODistributionGroup'

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

