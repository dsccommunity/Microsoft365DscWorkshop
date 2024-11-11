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
    $script:ResourceTypeTypeNameMapping = @{}

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
                        if ($null -ne $kvp.Value.Value)
                        {
                            Write-Verbose "Adding key: $key, value: $($kvp.Value.Value)"
                            $properties.Add($kvp.Name, $kvp.Value.Value)
                        }
                        elseif ($null -ne $kvp.Value.Values)
                        {
                            Write-Verbose "Adding key: $key, value: $($kvp.Values)"
                            if ($kvp.Value -is [Kingsland.MofParser.Models.Values.ComplexValueArray])
                            {
                                $properties.Add($kvp.Name, $kvp.Value.Values.ForEach({ $_.Name }))
                            }
                            elseif ($kvp.Value -is [Kingsland.MofParser.Models.Values.LiteralValueArray])
                            {
                                $properties.Add($kvp.Name, $kvp.Value.Values.ForEach({ $_.Value }))
                            }
                            else
                            {
                                throw (New-Object System.NotImplementedException)
                            }
                        }
                        else
                        {
                            if ($kvp.Value -is [Kingsland.MofParser.Models.Values.ComplexValueAlias])
                            {
                                Write-Verbose "Adding key: $key, value: $($kvp.Value)"
                                $properties.Add($kvp.Name, $kvp.Value.Name)
                            }
                            else
                            {
                                throw (New-Object System.NotImplementedException)
                            }
                        }
                    }
                }

                try
                {
                    $script:ResourceTypeTypeNameMapping.Add($selectedInstance.Alias, $selectedInstance.TypeName)
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

function Copy-YamlData
{
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Data,

        [Parameter()]
        [string[]]$ResourceTypes = @(),

        [Parameter()]
        [hashtable]$AllData
    )

    $copy = @{}
    $keys = $Data.Keys | ForEach-Object {
        if ($_ -notlike 'MSFT_*ref')
        {
            $_
        }
        else
        {
            if ($ResourceTypes -contains $ResourceTypeTypeNameMapping.$_)
            {
                $_
            }
        }
    }
    foreach ($key in $keys)
    {
        $value = $Data[$key]
        if ($value -is [System.Collections.IDictionary])
        {
            $copy[$key] = Copy-YamlData -Data $value -ResourceTypes $ResourceTypes -AllData $AllData
        }
        elseif ($value -is [System.Collections.IList])
        {
            $copy[$key] = @()
            foreach ($item in $value)
            {
                if ($item -is [System.Collections.IDictionary])
                {
                    $copy[$key] += Copy-YamlData -Data $item -ResourceTypes $ResourceTypes -AllData $AllData
                }
                else
                {
                    if ($item -like 'MSFT_*ref')
                    {
                        $copy[$key] += Get-YamlValue -Data $AllData -SearchKey $item
                    }
                    else
                    {
                        $copy[$key] += $item
                    }
                }
            }
        }
        else
        {
            if ($value -like 'MSFT_*ref')
            {
                $copy[$key] = Get-YamlValue -Data $AllData -SearchKey $value
            }
            else
            {
                $copy[$key] = $value
            }
        }
    }

    return $copy
}

function Get-YamlValue
{
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Data,
        [Parameter(Mandatory = $true)]
        [string]$SearchKey
    )

    function Search-Key
    {
        param (
            [hashtable]$Data,
            [string]$Key
        )

        foreach ($k in $Data.Keys)
        {
            if ($k -eq $Key)
            {
                return $Data[$k]
            }
            elseif ($Data[$k] -is [hashtable])
            {
                $result = Search-Key -Data $Data[$k] -Key $Key
                if ($result)
                {
                    return $result
                }
            }
            elseif ($Data[$k] -is [System.Collections.IList])
            {
                foreach ($item in $Data[$k])
                {
                    if ($item -is [hashtable])
                    {
                        $result = Search-Key -Data $item -Key $Key
                        if ($result)
                        {
                            return $result
                        }
                    }
                }
            }
        }
        return $null
    }

    $value = Search-Key -Data $Data -Key $SearchKey

    return $value
}
