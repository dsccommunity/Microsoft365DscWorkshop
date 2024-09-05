Add-Type -Path $PSScriptRoot\Kingsland.MofParser\Kingsland.MofParser.dll

function Get-MofFileInstances
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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

function Convert-MofToYaml
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string[]]$KeysToExclude = ('ModuleName', 'ModuleVersion', 'ResourceID', 'SourceInfo', 'TenantId', 'ConfigurationName', 'ActivateApprover')
    )

    $mofFiles = dir -Path $Path -Recurse -Filter *.mof
    $result = @{}

    foreach ($mofFile in $mofFiles)
    {
        $objects = @{}
        $mofInstances = Get-MofFileInstances -Path $mofFile.FullName

        $instanceNames = $mofInstances | Where-Object { $_.TypeName -ne 'OMI_ConfigurationDocument' } | Select-Object -ExpandProperty TypeName -Unique

        foreach ($instanceName in $instanceNames)
        {
            Write-Host "Processing instance name: $instanceName"
            $selectedInstances = $mofInstances | Where-Object { $_.TypeName -eq $instanceName }
            $keys = $selectedInstances.Properties.Name | Where-Object { $_ -notin $keysToExclude } | Sort-Object -Unique
            $isSingleInstance = $keys -contains 'IsSingleInstance'

            foreach ($selectedInstance in $selectedInstances)
            {
                Write-Host "Processing instance: $($selectedInstance.Alias)"
                $properties = @{}
                foreach ($key in $keys)
                {
                    $kvp = ($selectedInstance.Properties.Where({ $_.Name -eq $key }))[0]
                    if ($null -ne $kvp -or $kvp.Count -gt 0)
                    {
                        Write-Verbose "Adding key: $key, value: $($kvp.Value)"
                        $properties.Add($kvp.Name, $kvp.Value)
                    }
                }

                try
                {
                    $objects.Add($selectedInstance.Alias, $properties)
                }
                catch
                {
                    Write-Warning "Instance with alias $($selectedInstance.Alias) already exists"
                }

            }
        }

        $result.Add($mofFile.FullName.Split('\')[-3], $objects)

    }

    return $result

}
