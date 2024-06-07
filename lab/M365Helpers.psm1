function Get-M365DscNotInDesiredStateResource
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$DscState,

		[Parameter()]
		[switch]$ReturnAllProperties
	)

	$result = foreach ($resource in $DscState.ResourcesNotInDesiredState)
	{
		$FilterXML = @"
<QueryList>
    <Query Id="0" Path="M365DSC">
    <Select Path="M365DSC">*[System[Provider[@Name='MSFT_$($resource.ResourceName)'] and (EventID=1)]]</Select>
    </Query>
</QueryList>
"@
		$event = Get-WinEvent -FilterXml $FilterXML -MaxEvents 1

		$data = $event.Properties[0].Value -replace '<>', ''
		$xml = [xml]$data

		$params = if ($ReturnAllProperties)
		{
			$xml.M365DSCEvent.DesiredValues.Param
		}
		else
		{
			$xml.M365DSCEvent.ConfigurationDrift.ParametersNotInDesiredState.Param
		}

		@{
			ResourceName   = $resource.ResourceName
			ResourceId     = ($resource.InstanceName -split '::\[')[0]
			InDesiredState = $false
			Parameters     = foreach ($param in $params)
			{
				[ordered]@{
					Name         = $param.Name
					DesiredValue = if ($ReturnAllProperties)
					{
						$param.'#text'
					}
					else
					{
						$param.DesiredValue
					}
					CurrentValue = if ($ReturnAllProperties)
					{
						if ($xml.M365DSCEvent.CurrentValues.Param.Where({ $_.Name -eq $param.Name }))
						{
							$xml.M365DSCEvent.CurrentValues.Param.Where({ $_.Name -eq $param.Name }).'#text'
						}
						else
						{
							'NA'
						}
					}
					else
					{
						$param.CurrentValue
					}
				}
			}
		}
	}

	$result
}

function Get-M365DscInDesiredStateResource
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$DscState,

		[Parameter()]
		[switch]$ReturnAllProperties
	)

	$result = foreach ($resource in $DscState.ResourcesInDesiredState)
	{
		$FilterXML = @"
<QueryList>
    <Query Id="0" Path="M365DSC">
    <Select Path="M365DSC">*[System[Provider[@Name='MSFT_$($resource.ResourceName)'] and (EventID=2)]]</Select>
    </Query>
</QueryList>
"@
		$xml = $null
		if ($ReturnAllProperties)
		{
			$event = Get-WinEvent -FilterXml $FilterXML -MaxEvents 1 -ErrorAction SilentlyContinue
		}

		if ($event)
		{
			$data = $event.Properties[0].Value -replace '<>', ''
			$xml = [xml]$data
		}

		@{
			ResourceName   = $resource.ResourceName
			ResourceId     = ($resource.InstanceName -split '::\[')[0]
			InDesiredState = $true
			Parameters     = foreach ($param in $xml.M365DSCEvent.DesiredValues.Param)
			{
				[ordered]@{
					Name         = $param.Name
					CurrentValue = $param.'#text'
					DesiredValue = $param.'#text'
				}
			}
		}
	}

	$result
}

function Get-M365DscState
{
	[CmdletBinding()]
	param (
		[Parameter()]
		[switch]$ReturnAllProperties
	)

	$dscState = Test-DscConfiguration -Detailed
	$data = if ($dscState.InDesiredState)
	{
		Get-M365DscInDesiredStateResource -DscState $dscState -ReturnAllProperties:$ReturnAllProperties
	}
	else
	{
		Get-M365DscInDesiredStateResource -DscState $dscState -ReturnAllProperties:$ReturnAllProperties
		Get-M365DscNotInDesiredStateResource -DscState $dscState -ReturnAllProperties:$ReturnAllProperties
	}

	$data
}

function Write-M365DscStatusEvent
{
	[CmdletBinding()]
	param (
		[Parameter()]
		[switch]$ReturnAllProperties,

		[Parameter()]
		[switch]$PassThru
	)

	$dscResources = Get-M365DscState -ReturnAllProperties:$ReturnAllProperties

	$inDesiredState = -not [bool]($dscResources | Where-Object { -not $_.InDesiredState })
	$resourcesInDesiredState = @($dscResources | Where-Object { $_.InDesiredState })
	$resourcesNotInDesiredState = @($dscResources | Where-Object { -not $_.InDesiredState })

	$sb = [System.Text.StringBuilder]::new()
	if ($inDesiredState)
	{
		[void]$sb.Append(@"
DSC has not reported any resources that are not in the desired state.
The command used was: '`$DscState = Test-DscConfiguration -Verbose -Detailed'

These $($resourcesInDesiredState.Count) resource(s) are in desired state.

"@)

		[void]$sb.Append(($resourcesInDesiredState | ConvertTo-Yaml))

	}
	else
	{
		[void]$sb.Append(@"
DSC reports resources that are not in the desired state.
The command used was: '`$DscState = Test-DscConfiguration -Verbose -Detailed'

There are $($resourcesInDesiredState.Count) resource(s) in desired state and $($resourcesNotInDesiredState.Count) which is / are not.

The following resource(s) are not in the desired state:


"@)

		[void]$sb.Append(($resourcesNotInDesiredState | ConvertTo-Yaml))

		[void]$sb.AppendLine()
		[void]$sb.AppendLine(@"

These $($resourcesInDesiredState.Count) resource(s) are in desired state:

"@)

		[void]$sb.Append(($resourcesInDesiredState | ConvertTo-Yaml))
	}

	$eventParam = @{
		LogName = 'M365DSC'
		Source  = 'Microsoft365DSC'
		Message = $sb.ToString()
	}
	if ($inDesiredState)
	{
		$eventParam.Add('EntryType', 'Information')
		$eventParam.Add('EventId', 1000)
	}
	else
	{
		$eventParam.Add('EntryType', 'Warning')
		$eventParam.Add('EventId', 1001)
	}

	Write-EventLog @eventParam

	if ($PassThru)
	{
		[pscustomobject]@{
			InDesiredState             = $inDesiredState
			ResourcesInDesiredState    = $resourcesInDesiredState
			ResourcesNotInDesiredState = $resourcesNotInDesiredState
		}
	}
}

function Wait-DscLocalConfigurationManager
{
	[CmdletBinding()]
	param(
		[Parameter()]
		[switch]
		$DoNotWaitForProcessToFinish
	)

	Write-Verbose 'Checking if LCM is busy.'
	if ((Get-DscLocalConfigurationManager).LCMState -eq 'Busy')
	{
		Write-Host 'LCM is busy, waiting until LCM has finished the job...' -NoNewline
		while ((Get-DscLocalConfigurationManager).LCMState -eq 'Busy')
		{
			Start-Sleep -Seconds 1
			Write-Host . -NoNewline
		}
		Write-Host 'done. LCM is no longer busy.'
	}
	else
	{
		Write-Verbose 'LCM is not busy'
	}

	if (-not $DoNotWaitForProcessToFinish)
	{
		$lcmProcessId = (Get-PSHostProcessInfo | Where-Object { $_.AppDomainName -eq 'DscPsPluginWkr_AppDomain' -and $_.ProcessName -eq 'WmiPrvSE' }).ProcessId
		if ($lcmProcessId)
		{
			Write-Host "LCM process with ID $lcmProcessId is still running, waiting for the process to exit..." -NoNewline
			$lcmProcess = Get-Process -Id $lcmProcessId
			while (-not $lcmProcess.HasExited)
			{
				Write-Host . -NoNewline
				Start-Sleep -Seconds 2
			}
			Write-Host 'done. Process existed.'
		}
		else
		{
			Write-Verbose 'LCM process was not running.'
		}
	}
}
