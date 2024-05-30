configuration cAADRoleSetting {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADRoleSetting [String] #ResourceName
{
    DisplayName = [string]
    [AccessTokens = [string[]]]
    [ActivateApprover = [string[]]]
    [ActivationMaxDuration = [string]]
    [ActivationReqJustification = [bool]]
    [ActivationReqMFA = [bool]]
    [ActivationReqTicket = [bool]]
    [ActiveAlertNotificationAdditionalRecipient = [string[]]]
    [ActiveAlertNotificationDefaultRecipient = [bool]]
    [ActiveAlertNotificationOnlyCritical = [bool]]
    [ActiveApproveNotificationAdditionalRecipient = [string[]]]
    [ActiveApproveNotificationDefaultRecipient = [bool]]
    [ActiveApproveNotificationOnlyCritical = [bool]]
    [ActiveAssigneeNotificationAdditionalRecipient = [string[]]]
    [ActiveAssigneeNotificationDefaultRecipient = [bool]]
    [ActiveAssigneeNotificationOnlyCritical = [bool]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [ApprovaltoActivate = [bool]]
    [AssignmentReqJustification = [bool]]
    [AssignmentReqMFA = [bool]]
    [AuthenticationContextId = [string]]
    [AuthenticationContextName = [string]]
    [AuthenticationContextRequired = [bool]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [ElegibilityAssignmentReqJustification = [bool]]
    [ElegibilityAssignmentReqMFA = [bool]]
    [EligibleAlertNotificationAdditionalRecipient = [string[]]]
    [EligibleAlertNotificationDefaultRecipient = [bool]]
    [EligibleAlertNotificationOnlyCritical = [bool]]
    [EligibleApproveNotificationAdditionalRecipient = [string[]]]
    [EligibleApproveNotificationDefaultRecipient = [bool]]
    [EligibleApproveNotificationOnlyCritical = [bool]]
    [EligibleAssigneeNotificationAdditionalRecipient = [string[]]]
    [EligibleAssigneeNotificationDefaultRecipient = [bool]]
    [EligibleAssigneeNotificationOnlyCritical = [bool]]
    [EligibleAssignmentAlertNotificationAdditionalRecipient = [string[]]]
    [EligibleAssignmentAlertNotificationDefaultRecipient = [bool]]
    [EligibleAssignmentAlertNotificationOnlyCritical = [bool]]
    [EligibleAssignmentAssigneeNotificationAdditionalRecipient = [string[]]]
    [EligibleAssignmentAssigneeNotificationDefaultRecipient = [bool]]
    [EligibleAssignmentAssigneeNotificationOnlyCritical = [bool]]
    [Ensure = [string]{ Present }]
    [ExpireActiveAssignment = [string]]
    [ExpireEligibleAssignment = [string]]
    [Id = [string]]
    [ManagedIdentity = [bool]]
    [PermanentActiveAssignmentisExpirationRequired = [bool]]
    [PermanentEligibleAssignmentisExpirationRequired = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADRoleSetting'

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

