Add-Type -Path C:\Kingsland.MofParser-main\Kingsland.MofParser-main\src\Kingsland.MofParser\bin\Debug\net6.0\Kingsland.MofParser.dll

$mofPath = 'C:\Kingsland.MofParser-main\Kingsland.MofParser-main\src\Kingsland.MofParser.Sample\dsc\MyServer.mof'
$mofPath = 'C:\Kingsland.MofParser-main\Kingsland.MofParser-main\localhost.mof'
$mof = [Kingsland.MofParser.PowerShellDscHelper]::ParseMofFileInstances($mofPath)

$aadRoleSettings = $mof | Where-Object ClassName -eq MSFT_AADRoleSetting
$aadRoleSettingsProperties = foreach ($item in $aadRoleSettings)
{
    $h = [ordered]@{}
    $keysToExclude = 'ModuleName', 'ModuleVersion', 'ResourceID', 'SourceInfo', 'TenantId', 'ConfigurationName', 'ActivateApprover'
    $keys = $item.Properties.Keys | Where-Object { $_ -notin $keysToExclude } | Sort-Object
    foreach ($key in $keys)
    {
        if ($item.Properties.$key)
        {
            $h.Add($key, $item.Properties.$key)
        }
    }

    $h.Add('ApplicationId', '[x={ $azurebuildParameters."$($Node.Environment)".AzworkerServicePrincipalAppId }=]')
    $h.Add('CertificateThumbprint', '[x={ $azurebuildParameters."$($Node.Environment)".AzWorkerServicePrincipalCertificateThumbprint }=]')
    $h.Add('TenantId', '[x={ $azurebuildParameters."$($Node.Environment)".AzTenantId }=]')

    $h

}

$aadRoleSettingsProperties | ConvertTo-Yaml | Set-Clipboard
