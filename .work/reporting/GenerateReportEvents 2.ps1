#$dscState = Test-DscConfiguration -Verbose -Detailed

$result = foreach ($resource in $dscState.ResourcesNotInDesiredState)
{    
    $FilterXML = @"
<QueryList>
    <Query Id="0" Path="M365DSC">
    <Select Path="M365DSC">*[System[Provider[@Name='MSFT_$($resource.ResourceName)'] and (EventID=1)]]</Select>
    </Query>
</QueryList>
"@
    $events = Get-WinEvent -FilterXML $FilterXML -MaxEvents 1

    foreach ($event in $events)
    {
        $data = $event.Properties[0].Value -replace '<>', ''
        $xml = [xml]$data
    
        @{
            ResourceName = $resource.ResourceName
            Parameters = foreach ($param in $xml.M365DSCEvent.ConfigurationDrift.ParametersNotInDesiredState.Param)
            {
                [ordered]@{
                    Name = $param.Name
                    CurrentValue = $param.CurrentValue
                    DesiredValue = $param.DesiredValue
                }
            }
        }
    }
}

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
