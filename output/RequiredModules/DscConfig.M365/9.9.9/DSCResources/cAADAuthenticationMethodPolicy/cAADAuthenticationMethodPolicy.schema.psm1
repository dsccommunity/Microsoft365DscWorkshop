configuration cAADAuthenticationMethodPolicy {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADAuthenticationMethodPolicy [String] #ResourceName
{
    DisplayName = [string]
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Description = [string]]
    [Ensure = [string]{ Present }]
    [Id = [string]]
    [ManagedIdentity = [bool]]
    [PolicyMigrationState = [string]{ migrationComplete | migrationInProgress | preMigration | unknownFutureValue }]
    [PolicyVersion = [string]]
    [PsDscRunAsCredential = [PSCredential]]
    [ReconfirmationInDays = [UInt32]]
    [RegistrationEnforcement = [MSFT_MicrosoftGraphregistrationEnforcement]]
    [SystemCredentialPreferences = [MSFT_MicrosoftGraphsystemCredentialPreferences]]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADAuthenticationMethodPolicy'

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

