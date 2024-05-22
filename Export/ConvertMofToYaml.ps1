#Requires -Version 7.0

Add-Type -Path $PSScriptRoot\MofParser\Kingsland.MofParser.dll

function Get-MofFileClasses
{
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Path
    )

    begin
    {
        $mofClasses = @()
    }

    process
    {
        foreach ($p in $Path)
        {
            $p = Resolve-Path -Path $p
            $mofClasses += [Kingsland.MofParser.PowerShellDscHelper]::ParseMofFileInstances($p)
        }
    }

    end
    {
        $mofClasses
    }
}

$keysToExclude = 'ModuleName', 'ModuleVersion', 'ResourceID', 'SourceInfo', 'TenantId', 'ConfigurationName', 'ActivateApprover'
$objects = @{}
$c = Get-MofFileClasses -Path .\M365TenantConfig\localhost.mof
$c = Get-MofFileClasses -Path D:\Git\Microsoft365DscWorkshop\output\MOF\Dev\LcmNew365Dev.mof

$instancesNames = $c.ClassName | Where-Object { $_.ClassName -ne 'OMI_ConfigurationDocument' -and $_.ClassName -eq 'MSFT_AADTenantDetails' } | Select-Object -Unique

foreach ($instancesName in $instancesNames)
{
    $selectedInstances = $c | Where-Object { $_.ClassName -eq $instancesName }
    $keys = $selectedInstances.Properties.Keys | Where-Object { $_ -notin $keysToExclude } | Sort-Object
    $isSingleInstance = $keys -contains 'IsSingleInstance'

    foreach ($selectedInstance in $selectedInstances)
    {
        $properties = @{}
        foreach ($key in $keys)
        {
            if ($selectedInstance.Properties.$key)
            {
                $properties.Add($key, $selectedInstance.Properties.$key)
            }
        }

        $properties.Add('ApplicationId', '[x={ $azurebuildParameters."$($Node.Environment)".AzworkerServicePrincipalAppId }=]')
        $properties.Add('CertificateThumbprint', '[x={ $azurebuildParameters."$($Node.Environment)".AzWorkerServicePrincipalCertificateThumbprint }=]')
        $properties.Add('TenantId', '[x={ $azurebuildParameters."$($Node.Environment)".AzTenantId }=]')

        $resourceName = ($selectedInstance.Properties.ResourceID -split '\[|\]')[1]
        $objects.Add($resourceName, $properties)
    }

    $objects.Add($instance.ClassName, $properties)

}

$objects | ConvertTo-Yaml | Set-Clipboard
