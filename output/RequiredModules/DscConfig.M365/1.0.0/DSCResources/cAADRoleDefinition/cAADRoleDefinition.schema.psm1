configuration cAADRoleDefinition {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADRoleDefinition [String] #ResourceName
{
    DisplayName = [string]
    IsEnabled = [bool]
    RolePermissions = [string[]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Description = [string]]
    [Ensure = [string]{ Absent | Present }]
    [Id = [string]]
    [ManagedIdentity = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [ResourceScopes = [string[]]]
    [TemplateId = [string]]
    [TenantId = [string]]
    [Version = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADRoleDefinition'

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

