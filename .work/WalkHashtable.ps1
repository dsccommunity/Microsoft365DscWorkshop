function Step-Hashtable {
    param (
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    foreach ($key in $InputObject.Keys) {

        $value = $InputObject."$key"
        foreach ($v in $value) {
            if ($v.GetType().FullName -eq 'FileProvider')
            {
                $v = $v.ToHashTable()
            }
            if ($v.GetType().FullName -in 'System.Collections.Hashtable', 'System.Collections.Specialized.OrderedDictionary') {
                Step-Hashtable -InputObject $v
            }
            else {
                "$($key) - $($v)"
            }
        }
    }

}

$files = dir -Recurse ..\source -Filter *.yml

#$d = New-DatumStructure -DefinitionFile ..\source\Datum.yml
$values = foreach ($file in $files)
{
    $hash = $file | Get-Content | ConvertFrom-Yaml
    Step-Hashtable -InputObject $hash
}

$values -like '*ENC=*'
