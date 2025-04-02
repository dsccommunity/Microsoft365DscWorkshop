#$dscState = Test-DscConfiguration -Verbose -Detailed

function NotInDesiredState
{
    param (
        [switch]$ReturnAllProperties
    )

    $moduleInfo = Get-Module -Name Microsoft365DSC -ListAvailable | Where-Object Version -eq $resource.ModuleVersion | Select-Object -First 1
    $resourceKeyProperties = Get-DscResourceProperty -ModuleInfo $moduleInfo -ResourceName $resource.ResourceName | Where-Object { $_.IsKey }

    $result = foreach ($resource in $dscState.ResourcesNotInDesiredState)
    {
        $FilterXML = @"
<QueryList>
    <Query Id="0" Path="M365DSC">
    <Select Path="M365DSC">*[System[Provider[@Name='MSFT_$($resource.ResourceName)'] and (EventID=1)]]</Select>
    </Query>
</QueryList>
"@
        $event = Get-WinEvent -FilterXML $FilterXML -MaxEvents 1

        $data = $event.Properties[0].Value -replace '<>', ''
        $xml = [xml]$data

        $keyValues = foreach ($resourceKeyProperty in $resourceKeyProperties)
        {
            ($xml.M365DSCEvent.DesiredValues.Param | Where-Object Name -eq $resourceKeyProperty.Name).'#text'
        }

        $params = if ($ReturnAllProperties)
        {
            $xml.M365DSCEvent.DesiredValues.Param
        }
        else
        {
            $xml.M365DSCEvent.ConfigurationDrift.ParametersNotInDesiredState.Param
        }

        @{
            ResourceName = $resource.ResourceName
            ResourceId = $keyValues -join '_'
            InDesiredState = $false
            Parameters = foreach ($param in $params)
            {
                [ordered]@{
                    Name = $param.Name
                    DesiredValue = $param.'#text'
                    CurrentValue = if ($xml.M365DSCEvent.CurrentValues.Param.Where({ $_.Name -eq $param.Name })) {
                        $xml.M365DSCEvent.CurrentValues.Param.Where({ $_.Name -eq $param.Name }).'#text'
                    }
                    else
                    {
                        'NA'
                    }
                }
            }
        }
    }

    $result
}

function InDesiredState
{
    $moduleInfo = Get-Module -Name Microsoft365DSC -ListAvailable | Where-Object Version -eq $resource.ModuleVersion | Select-Object -First 1
    $resourceKeyProperties = Get-DscResourceProperty -ModuleInfo $moduleInfo -ResourceName $resource.ResourceName | Where-Object { $_.IsKey }

    $result = foreach ($resource in $dscState.ResourcesInDesiredState)
    {
        $FilterXML = @"
<QueryList>
    <Query Id="0" Path="M365DSC">
    <Select Path="M365DSC">*[System[Provider[@Name='MSFT_$($resource.ResourceName)'] and (EventID=2)]]</Select>
    </Query>
</QueryList>
"@
        $event = Get-WinEvent -FilterXML $FilterXML -MaxEvents 1

        $data = $event.Properties[0].Value -replace '<>', ''
        $xml = [xml]$data

        $keyValues = foreach ($resourceKeyProperty in $resourceKeyProperties)
        {
            ($xml.M365DSCEvent.DesiredValues.Param | Where-Object Name -eq $resourceKeyProperty.Name).'#text'
        }

        @{
            ResourceName = $resource.ResourceName
            ResourceId = $keyValues -join '_'
            InDesiredState = $true
            Parameters = foreach ($param in $xml.M365DSCEvent.DesiredValues.Param)
            {
                [ordered]@{
                    Name = $param.Name
                    CurrentValue = $param.'#text'
                    DesiredValue = $param.'#text'
                }
            }
        }
    }

    $result
}

$info = if ($dscState.InDesiredState)
{
    InDesiredState
}
else
{
    NotInDesiredState -ReturnAllProperties
    InDesiredState
}

$info
return
else
{
    $moduleInfo = Get-Module -Name Microsoft365DSC -ListAvailable | Where-Object Version -eq $resource.ModuleVersion | Select-Object -First 1
    $resourceKeyProperties = Get-DscResourceProperty -ModuleInfo $moduleInfo -ResourceName $resource.ResourceName | Where-Object { $_.IsKey }

    $result = foreach ($resource in $dscState.ResourcesInDesiredState)
    {
        $FilterXML = @"
<QueryList>
    <Query Id="0" Path="M365DSC">
    <Select Path="M365DSC">*[System[Provider[@Name='MSFT_$($resource.ResourceName)'] and (EventID=1)]]</Select>
    </Query>
</QueryList>
"@
        $event = Get-WinEvent -FilterXML $FilterXML -MaxEvents 1

        $data = $event.Properties[0].Value -replace '<>', ''
        $xml = [xml]$data

        $keyValues = foreach ($resourceKeyProperty in $resourceKeyProperties)
        {
            ($xml.M365DSCEvent.DesiredValues.Param | Where-Object Name -eq $resourceKeyProperty.Name).'#text'
        }

        @{
            ResourceName = $resource.ResourceName
            ResourceId = $keyValues -join '_'
            Parameters = foreach ($param in $xml.M365DSCEvent.DesiredValues.Param)
            {
                [ordered]@{
                    Name = $param.Name
                    CurrentValue = $param.CurrentValue
                    DesiredValue = $param.DesiredValue
                }
            }
        }
    }

    $result
}

$info

return

if ($null -ne $result)
{
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append(@"
DSC reports resources that are not in the desired state.
The command used was: '`$dscState = Test-DscConfiguration -Verbose -Detailed'

There are $($dscState.ResourcesInDesiredState.Count) resource(s) in desired state and $($dscState.ResourcesNotInDesiredState.Count) which are not.

The following resource(s) are not in the desired state:


"@)

    foreach ($resource in $dscState.ResourcesInDesiredState)
    {

    }

    foreach ($item in $result)
    {
        [void]$sb.Append(($item | ConvertTo-Yaml))
        [void]$sb.AppendLine()
    }

    [void]$sb.AppendLine()
    [void]$sb.AppendLine("These $($dscState.ResourcesInDesiredState.Count) resources are in desired state:")
    [void]$sb.AppendLine()
    foreach ($resource in $dscState.ResourcesInDesiredState)
    {
        [void]$sb.AppendLine('- ' + $resource.ResourceName)
    }

    $eventParam = @{
        LogName = 'M365DSC'
        Source = 'Microsoft365DSC'
        EntryType = 'Warning'
        EventId = 1001
        Message =$sb.ToString()
    }

    Write-EventLog @eventParam
}
else
{
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append(@"
DSC has not reported any resources that are not in the desired state.
The command used was: '`$dscState = Test-DscConfiguration -Verbose -Detailed'

There are $($dscState.ResourcesInDesiredState.Count) resource(s) in desired state.


"@)

    foreach ($resource in $dscState.ResourcesInDesiredState)
    {
        [void]$sb.AppendLine('- ' + $resource.ResourceName)
    }

    $eventParam = @{
        LogName = 'M365DSC'
        Source = 'Microsoft365DSC'
        EntryType = 'Information'
        EventId = 1000
        Message =$sb.ToString()
    }
    Write-EventLog @eventParam
}
