#Region '.\Private\Assert-DscModuleResourceIsValid.ps1' -1

function Assert-DscModuleResourceIsValid
{
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline)]
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]
        $DscResources
    )

    begin
    {
        Write-Verbose "Testing for valid resources."
        $FailedDscResources = @()
    }

    process
    {
        foreach($DscResource in $DscResources) {
            $FailedDscResources += Get-FailedDscResource -DscResource $DscResource
        }
    }

    end
    {
        if ($FailedDscResources.Count -gt 0)
        {
            Write-Verbose "Found failed resources."
            foreach ($resource in $FailedDscResources)
            {

                Write-Warning "`t`tFailed Resource - $($resource.Name) ($($resource.Version))"
            }

            throw "One or more resources is invalid."
        }
    }
}
#EndRegion '.\Private\Assert-DscModuleResourceIsValid.ps1' 38
#Region '.\Private\Get-RequiredModulesFromMOF.ps1' -1

#author Iain Brighton, from here: https://gist.github.com/iainbrighton/9d3dd03630225ee44126769c5d9c50a9
# Not sure that takes all possibilities into account:
# i.e. when using Import-DscResource -Name ResourceName #even if it's bad practice
# Also need to return PSModuleInfo, instead of @{ModuleName='<version>'}
# Then probably worth promoting to public
function Get-RequiredModulesFromMOF {
    <#
    .SYNOPSIS
        Scans a Desired State Configuration .mof file and returns the declared/
        required modules.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [System.String] $Path
    )
    process {

        $modules = @{ }
        $moduleName = $null
        $moduleVersion = $null

        Get-Content -Path $Path -Encoding Unicode | ForEach-Object {

            $line = $_;
            if ($line -match '^\s?Instance of') {
                ## We have a new instance so write the existing one
                if (($null -ne $moduleName) -and ($null -ne $moduleVersion)) {

                    $modules[$moduleName] = $moduleVersion;
                    $moduleName = $null
                    $moduleVersion = $null
                    Write-Verbose "Module Instance found: $moduleName $moduleVersion"
                }
            }
            elseif ($line -match '(?<=^\s?ModuleName\s?=\s?")\S+(?=";)') {

                ## Ignore the default PSDesiredStateConfiguration module
                if ($Matches[0] -notmatch 'PSDesiredStateConfiguration') {
                    $moduleName = $Matches[0]
                    Write-Verbose "Found Module Name $modulename"
                }
                else {
                    Write-Verbose 'Excluding PSDesiredStateConfiguration module'
                }
            }
            elseif ($line -match '(?<=^\s?ModuleVersion\s?=\s?")\S+(?=";)') {
                $moduleVersion = $Matches[0] -as [System.Version]
                Write-Verbose "Module version = $moduleVersion"
            }
        }

        Write-Output -InputObject $modules
    } #end process
} #end function Get-RequiredModulesFromMOF
#EndRegion '.\Private\Get-RequiredModulesFromMOF.ps1' 56
#Region '.\Private\Get-StandardCimType.ps1' -1

function Get-StandardCimType
{
    $types = @{
        Boolean               = 'System.Boolean'
        UInt8                 = 'System.Byte'
        SInt8                 = 'System.SByte'
        UInt16                = 'System.UInt16'
        SInt16                = 'System.Int16'
        UInt32                = 'System.UInt32'
        SInt32                = 'System.Int32'
        UInt64                = 'System.UInt64'
        SInt64                = 'System.Int64'
        Real32                = 'System.Single'
        Real64                = 'System.Double'
        Char16                = 'System.Char'
        DateTime              = 'System.DateTime'
        String                = 'System.String'
        Reference             = 'Microsoft.Management.Infrastructure.CimInstance'
        Instance              = 'Microsoft.Management.Infrastructure.CimInstance'
        BooleanArray          = 'System.Boolean[]'
        UInt8Array            = 'System.Byte[]'
        SInt8Array            = 'System.SByte[]'
        UInt16Array           = 'System.UInt16[]'
        SInt16Array           = 'System.Int16[]'
        UInt32Array           = 'System.UInt32[]'
        SInt32Array           = 'System.Int32[]'
        UInt64Array           = 'System.UInt64[]'
        SInt64Array           = 'System.Int64[]'
        Real32Array           = 'System.Single[]'
        Real64Array           = 'System.Double[]'
        Char16Array           = 'System.Char[]'
        DateTimeArray         = 'System.DateTime[]'
        StringArray           = 'System.String[]'

        MSFT_Credential       = 'System.Management.Automation.PSCredential'
        'MSFT_KeyValuePair[]' = 'System.Collections.Hashtable'
        MSFT_KeyValuePair     = 'System.Collections.Hashtable'
    }

    try
    {
        $types.GetEnumerator() | ForEach-Object {
            $null = Invoke-Expression -Command "[$($_.Value)]" -ErrorAction Stop
            [PSCustomObject]@{
                CimType    = $_.Key
                DotNetType = $_.Value
            }
        }
    }
    catch
    {
        Write-Error -Message "Failed to load CIM Types. The error was: $($_.Exception.Message)"
    }
}
#EndRegion '.\Private\Get-StandardCimType.ps1' 55
#Region '.\Private\Resolve-ModuleMetadataFile.ps1' -1


function Resolve-ModuleMetadataFile {
    [cmdletbinding(DefaultParameterSetName = 'ByDirectoryInfo')]
    param (
        [parameter(
            ParameterSetName = 'ByPath',
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
        [string]
        $Path,
        [parameter(
            ParameterSetName = 'ByDirectoryInfo',
            Mandatory,
            ValueFromPipeline
        )]
        [System.IO.DirectoryInfo]
        $InputObject

    )

    process {
        $MetadataFileFound = $true
        $MetadataFilePath = ''
        Write-Verbose "Using Parameter set - $($PSCmdlet.ParameterSetName)"
        switch ($PSCmdlet.ParameterSetName) {
            'ByPath' {
                Write-Verbose "Testing Path - $path"
                if (Test-Path $Path) {
                    Write-Verbose "`tFound $path."
                    $item = (Get-Item $Path)
                    if ($item.psiscontainer) {
                        Write-Verbose "`t`tIt is a folder."
                        $ModuleName = Split-Path $Path -Leaf
                        $MetadataFilePath = Join-Path $Path "$ModuleName.psd1"
                        $MetadataFileFound = Test-Path $MetadataFilePath
                    }
                    else {
                        if ($item.Extension -like '.psd1') {
                            Write-Verbose "`t`tIt is a module metadata file."
                            $MetadataFilePath = $item.FullName
                            $MetadataFileFound = $true
                        }
                        else {
                            $ModulePath = Split-Path $Path
                            Write-Verbose "`t`tSearching for module metadata folder in $ModulePath"
                            $ModuleName = Split-Path $ModulePath -Leaf
                            Write-Verbose "`t`tModule name is $ModuleName."
                            $MetadataFilePath = Join-Path $ModulePath "$ModuleName.psd1"
                            Write-Verbose "`t`tChecking for $MetadataFilePath."
                            $MetadataFileFound = Test-Path $MetadataFilePath
                        }
                    }
                }
                else {
                    $MetadataFileFound = $false
                }
            }
            'ByDirectoryInfo' {
                $ModuleName = $InputObject.Name
                $MetadataFilePath = Join-Path $InputObject.FullName "$ModuleName.psd1"
                $MetadataFileFound = Test-Path $MetadataFilePath
            }

        }

        if ($MetadataFileFound -and (-not [string]::IsNullOrEmpty($MetadataFilePath))) {
            Write-Verbose "Found a module metadata file at $MetadataFilePath."
            Convert-path $MetadataFilePath
        }
        else {
            Write-Error "Failed to find a module metadata file at $MetadataFilePath."
        }
    }
}
#EndRegion '.\Private\Resolve-ModuleMetadataFile.ps1' 76
#Region '.\Public\Clear-CachedDscResource.ps1' -1

function Clear-CachedDscResource {
    [cmdletbinding(SupportsShouldProcess=$true)]
    param()

    if ($pscmdlet.ShouldProcess($env:computername)) {
        Write-Verbose 'Stopping any existing WMI processes to clear cached resources.'

        ### find the process that is hosting the DSC engine
        $dscProcessID = Get-WmiObject msft_providers |
          Where-Object {$_.provider -like 'dsccore'} |
            Select-Object -ExpandProperty HostProcessIdentifier

        ### Stop the process
        if ($dscProcessID -and $pscmdlet.ShouldProcess('DSC Process')) {
            Get-Process -Id $dscProcessID | Stop-Process
        }
        else {
            Write-Verbose 'Skipping killing the DSC Process'
        }

        Write-Verbose 'Clearing out any tmp WMI classes from tested resources.'
        Get-DscResourceWmiClass -class tmp* | remove-DscResourceWmiClass
    }
}
#EndRegion '.\Public\Clear-CachedDscResource.ps1' 25
#Region '.\Public\Compress-DscResourceModule.ps1' -1

function Compress-DscResourceModule {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DscBuildOutputModules,

        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [psmoduleinfo[]]
        $Modules
    )

    begin {
        if (-not (Test-Path -Path $DscBuildOutputModules)) {
            mkdir -Path $DscBuildOutputModules -Force
        }
    }
    Process {
        Foreach ($module in $Modules) {
            if ($PSCmdlet.ShouldProcess("Compress $Module $($Module.Version) from $(Split-Path -parent $Module.Path) to $DscBuildOutputModules")) {
                Write-Verbose "Publishing Module $(Split-Path -parent $Module.Path) to $DscBuildOutputModules"
                $destinationPath = Join-Path -Path $DscBuildOutputModules -ChildPath "$($module.Name)_$($module.Version).zip"
                Compress-Archive -Path "$($module.ModuleBase)\*" -DestinationPath $destinationPath

                (Get-FileHash -Path $destinationPath).Hash | Set-Content -Path "$destinationPath.checksum" -NoNewline
            }
        }
    }
}
#EndRegion '.\Public\Compress-DscResourceModule.ps1' 32
#Region '.\Public\Find-ModuleToPublish.ps1' -1

function Find-ModuleToPublish {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory
        )]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $DscBuildSourceResources,

        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.Commands.ModuleSpecification[]]
        $ExcludedModules = $null,

        [Parameter(
            Mandatory
        )]
        [ValidateNotNullOrEmpty()]
        $DscBuildOutputModules
    )

    $ModulesAvailable = Get-ModuleFromFolder -ModuleFolder $DscBuildSourceResources -ExcludedModules $ExcludedModules

    Foreach ($Module in $ModulesAvailable) {
        $publishTargetZip =  [System.IO.Path]::Combine(
                                            $DscBuildOutputModules,
                                            "$($module.Name)_$($module.version).zip"
                                            )
        $publishTargetZipCheckSum =  [System.IO.Path]::Combine(
                                            $DscBuildOutputModules,
                                            "$($module.Name)_$($module.version).zip.checksum"
                                            )

        $zipExists      = Test-Path -Path $publishTargetZip
        $checksumExists = Test-Path -Path $publishTargetZipCheckSum

        if (-not ($zipExists -and $checksumExists))
        {
            Write-Debug "ZipExists = $zipExists; CheckSum exists = $checksumExists"
            Write-Verbose -Message "Adding $($Module.Name)_$($Module.Version) to the Modules To Publish"
            Write-Output -inputObject $Module
        }
        else {
            Write-Verbose -Message "$($Module.Name) does not need to be published"
        }
    }
}
#EndRegion '.\Public\Find-ModuleToPublish.ps1' 48
#Region '.\Public\Get-DscCimInstanceReference.ps1' -1

function Get-DscCimInstanceReference {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceName,

        [Parameter(Mandatory = $true)]
        [string]
        $ParameterName,

        [Parameter()]
        [object]
        $Data
    )

    if ($Script:allDscResourcePropertiesTable) {
        if ($allDscResourcePropertiesTable.ContainsKey("$($ResourceName)-$($ParameterName)")) {
            $p = $allDscResourcePropertiesTable."$($ResourceName)-$($ParameterName)"
            $typeConstraint = $p.TypeConstraint -replace '\[\]', ''
            Get-DscSplattedResource -ResourceName $typeConstraint -Properties $Data -NoInvoke
        }
    }
    else {
        Write-Host "No DSC Resource Properties metadata was found, cannot translate CimInstance parameters. Call 'Initialize-DscResourceMetaInfo' first is this is needed."
    }
}
#EndRegion '.\Public\Get-DscCimInstanceReference.ps1' 27
#Region '.\Public\Get-DscFailedResource.ps1' -1

function Get-DscFailedResource {
    [cmdletbinding()]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]
        $DscResource
    )

    Process {
        foreach ($resource in $DscResource) {
            if ($resource.Path) {
                $resourceNameOrPath = Split-Path $resource.Path -Parent
            }
            else {
                $resourceNameOrPath = $resource.Name
            }

            if (-not (Test-xDscResource -Name $resourceNameOrPath)) {
                Write-Warning "`tResources $($_.name) is invalid."
                $resource
            }
            else {
                Write-Verbose ('DSC Resource Name {0} {1} is Valid' -f $resource.Name, $resource.Version)
            }
        }
    }
}
#EndRegion '.\Public\Get-DscFailedResource.ps1' 31
#Region '.\Public\Get-DscResourceFromModuleInFolder.ps1' -1

function Get-DscResourceFromModuleInFolder
{
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleFolder,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSModuleInfo[]]
        $Modules
    )

    begin
    {
        $oldPSModulePath = $env:PSModulePath
        $env:PSModulePath = $ModuleFolder

        Write-Verbose "Retrieving all resources for '$ModuleFolder'."
        $dscResources = Get-DscResource

        $env:PSModulePath = $oldPSModulePath

        $result = @()
    }

    process
    {
        Write-Verbose "Filtering the $($dscResources.Count) resources."
        Write-Debug ($dscResources | Format-Table -AutoSize | Out-String)

        foreach ($dscResource in $dscResources)
        {
            if ($null -eq $dscResource.Module)
            {
                Write-Debug "Excluding resource '$($dscResource.Name) - $($dscResource.Version)', it is not part of a module."
                continue
            }

            foreach ($module in $Modules)
            {

                if (-not (Compare-Object -ReferenceObject $dscResource.Module -DifferenceObject $Module -Property ModuleType, Version, Name))
                {
                    Write-Debug "Resource $($dscResource.Name) matches one of the supplied Modules."
                    Write-Debug "`tIncluding $($dscResource.Name) $($dscResource.Version)"
                    $result += $dscResource
                }
            }
        }
    }

    end
    {
        $result
    }
}
#EndRegion '.\Public\Get-DscResourceFromModuleInFolder.ps1' 60
#Region '.\Public\Get-DscResourceProperty.ps1' -1

function Get-DscResourceProperty
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ModuleInfo')]
        [System.Management.Automation.PSModuleInfo]
        $ModuleInfo,

        [Parameter(Mandatory, ParameterSetName = 'ModuleName')]
        [string]
        $ModuleName,

        [Parameter(Mandatory)]
        [string]
        $ResourceName
    )

    $ModuleInfo = if ($ModuleName)
    {
        Import-Module -Name $ModuleName -PassThru -Force
    }
    else
    {
        Import-Module -Name $ModuleInfo.Name -PassThru -Force
    }

    [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ClearCache()
    $functionsToDefine = New-Object -TypeName 'System.Collections.Generic.Dictionary[string,ScriptBlock]'([System.StringComparer]::OrdinalIgnoreCase)
    [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::LoadDefaultCimKeywords($functionsToDefine)

    $schemaFilePath = $null
    $keywordErrors = New-Object -TypeName 'System.Collections.ObjectModel.Collection[System.Exception]'

    $foundCimSchema = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportCimKeywordsFromModule($ModuleInfo, $ResourceName, [ref] $SchemaFilePath, $functionsToDefine, $keywordErrors)
    if ($foundCimSchema)
    {
        $foundScriptSchema = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportScriptKeywordsFromModule($ModuleInfo, $ResourceName, [ref] $SchemaFilePath, $functionsToDefine)
    }
    else
    {
        [System.Collections.Generic.List[string]]$resourceNameAsList = $ResourceName
        [void][Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportClassResourcesFromModule($ModuleInfo, $resourceNameAsList, $functionsToDefine)
    }

    $resourceProperties = ([System.Management.Automation.Language.DynamicKeyword]::GetKeyword($ResourceName)).Properties

    foreach ($key in $resourceProperties.Keys)
    {
        $resourceProperty = $resourceProperties.$key

        $dscClassParameterInfo = & $ModuleInfo {

            param (
                [Parameter(Mandatory = $true)]
                [string]$TypeName
            )

            $result = @{
                ElementType         = $null
                Type                = $null
                IsArray             = $false
            }

            try
            {
                $result.Type = Invoke-Expression "[$($TypeName)]"

                if ($result.Type.IsArray)
                {
                    $result.ElementType = $result.Type.GetElementType().FullName
                    $result.IsArray = $true
                }
            }
            catch
            {
            }

            return $result

        } $resourceProperty.TypeConstraint

        $isArrayType = if ($null -ne $dscClassParameterInfo.Type){
            $dscClassParameterInfo.IsArray
        }
        else
        {
            $resourceProperty.TypeConstraint -match '.+\[\]'
        }

        [PSCustomObject]@{
            Name                = $resourceProperty.Name
            ModuleName          = $ModuleInfo.Name
            ResourceName        = $ResourceName
            TypeConstraint      = $resourceProperty.TypeConstraint
            Attributes          = $resourceProperty.Attributes
            Values              = $resourceProperty.Values
            ValueMap            = $resourceProperty.ValueMap
            Mandatory           = $resourceProperty.Mandatory
            IsKey               = $resourceProperty.IsKey
            Range               = $resourceProperty.Range
            IsArray             = $isArrayType
            ElementType         = $dscClassParameterInfo.ElementType
            Type                = $dscClassParameterInfo.Type
        }
    }
}
#EndRegion '.\Public\Get-DscResourceProperty.ps1' 97
#Region '.\Public\Get-DscResourceWmiClass.ps1' -1

function Get-DscResourceWmiClass {
    <#
        .Synopsis
            Retrieves WMI classes from the DSC namespace.
        .Description
            Retrieves WMI classes from the DSC namespace.
        .Example
            Get-DscResourceWmiClass -Class tmp*
        .Example
            Get-DscResourceWmiClass -Class 'MSFT_UserResource'
    #>
    param (
        #The WMI Class name search for.  Supports wildcards.
        [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]
        $Class
    )
    begin {
        $DscNamespace = "root/Microsoft/Windows/DesiredStateConfiguration"
    }
    process {
        Get-wmiobject -Namespace $DscNamespace -list @psboundparameters
    }
}
#EndRegion '.\Public\Get-DscResourceWmiClass.ps1' 26
#Region '.\Public\Get-DscSplattedResource.ps1' -1

function Get-DscSplattedResource
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $ResourceName,

        [Parameter()]
        [String]
        $ExecutionName,

        [Parameter()]
        [hashtable]
        $Properties,

        [Parameter()]
        [switch]
        $NoInvoke
    )

    if (-not $script:allDscResourcePropertiesTable -and -not $script:allDscResourcePropertiesTableWarningShown) {
        Write-Warning -Message "The 'allDscResourcePropertiesTable' is not defined. This will be an expensive operation. Resources with MOF sub-types are only supported when calling 'Initialize-DscResourceMetaInfo' once before starting the compilation process."
        $script:allDscResourcePropertiesTableWarningShown = $true
    }

    $standardCimTypes = Get-StandardCimType

    # Remove Case Sensitivity of ordered Dictionary or Hashtables
    $Properties = @{} + $Properties

    $stringBuilder = [System.Text.StringBuilder]::new()
    $null = $stringBuilder.AppendLine("Param([hashtable]`$Parameters)")
    $null = $stringBuilder.AppendLine()

    if ($ExecutionName)
    {
        $null = $stringBuilder.AppendLine("$ResourceName '$ExecutionName' {")
    }
    else
    {
        $null = $stringBuilder.AppendLine("$ResourceName {")
    }

    foreach ($propertyName in $Properties.Keys)
    {
        $cimProperty = Get-CimType -DscResourceName $ResourceName -PropertyName $propertyName
        if ($cimProperty)
        {
            Write-CimProperty -StringBuilder $stringBuilder -CimProperty $cimProperty -Path $propertyName -ResourceName $ResourceName
        }
        else
        {
            $null = $stringBuilder.AppendLine("$propertyName = `$Parameters['$propertyName']")
        }
    }

    $null = $stringBuilder.AppendLine("}")
    Write-Debug -Message ('Generated Resource Block = {0}' -f $stringBuilder.ToString())

    if ($NoInvoke)
    {
        [scriptblock]::Create($stringBuilder.ToString())
    }
    else
    {
        if ($Properties)
        {
            [scriptblock]::Create($stringBuilder.ToString()).Invoke($Properties)
        } else
        {
            [scriptblock]::Create($stringBuilder.ToString()).Invoke()
        }
    }
}

function Write-CimProperty
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Text.StringBuilder]$StringBuilder,

        [Parameter(Mandatory = $true)]
        [object]$CimProperty,

        [Parameter(Mandatory = $true)]
        [string[]]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ResourceName
    )

    $null = $StringBuilder.Append("$($CimProperty.Name) = ")
    if ($CimProperty.IsArray -or $CimProperty.PropertyType.IsArray -or $CimProperty.CimType -eq 'InstanceArray') {
        $null = $StringBuilder.Append("@(`n")

        $pathValue = Get-PropertiesData -Path $Path

        $i = 0
        foreach ($element in $pathValue)
        {
            $p = $Path + $i
            Write-CimPropertyValue -StringBuilder $StringBuilder -CimProperty $CimProperty -Path $p -ResourceName $ResourceName
            $i++
        }

        $null = $StringBuilder.Append(")`n")
    }
    else
    {
        Write-CimPropertyValue -StringBuilder $StringBuilder -CimProperty $CimProperty -Path $Path -ResourceName $ResourceName
    }
}

function Write-CimPropertyValue
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Text.StringBuilder]$StringBuilder,

        [Parameter(Mandatory = $true)]
        [object]$CimProperty,

        [Parameter(Mandatory = $true)]
        [string[]]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ResourceName
    )

    $type = Get-DynamicTypeObject -Object $CimProperty
    if ($type.IsArray)
    {
        if ($type -is [pscustomobject])
        {
            $typeName = $type.TypeConstraint -replace '\[\]', ''
            $typeProperties = ($allDscSchemaClasses.Where({ $_.CimClassName -eq $typeName -and $_.ResourceName -eq $ResourceName })).CimClassProperties
        }
        else
        {
            $typeName = $type.Name -replace '\[\]', ''
            $typeProperties = $type.GetElementType().GetProperties().Where({$_.CustomAttributes.AttributeType.Name -eq 'DscPropertyAttribute' })
        }
    }
    else
    {
        if ($type -is [pscustomobject])
        {
            $typeName = $type.TypeConstraint
            $typeProperties = ($allDscSchemaClasses.Where({ $_.CimClassName -eq $typeName -and $_.ResourceName -eq $ResourceName })).CimClassProperties
        }
        elseif ($type -is [type])
        {
            $typeName = $type.Name
            $typeProperties = $type.GetProperties().Where({$_.CustomAttributes.AttributeType.Name -eq 'DscPropertyAttribute' })
        }
        elseif ($type.GetType().FullName -eq 'Microsoft.Management.Infrastructure.Internal.Data.CimClassPropertyOfClass')
        {
            $typeName = $type.ReferenceClassName
            $typeProperties = ($allDscSchemaClasses.Where({ $_.CimClassName -eq $typeName -and $_.ResourceName -eq $ResourceName })).CimClassProperties
        }
    }

    $null = $StringBuilder.AppendLine($typeName)
    $null = $StringBuilder.AppendLine('{')

    foreach ($property in $typeProperties)
    {
        #function Get-IsCimType
        $isCimProperty = if ($property.GetType().Name -eq 'CimClassPropertyOfClass')
        {
            if ($property.CimType -in 'Instance', 'InstanceArray')
            {
                $true
            }
            else
            {
                $property.CimType -notin $standardCimTypes.CimType
            }
        }
        else
        {
            $property.PropertyType.FullName -notin $standardCimTypes.DotNetType
        }

        $pathValue = Get-PropertiesData -Path ($Path + $property.Name)

        if ($null -ne $pathValue)
        {
            if ($isCimProperty)
            {
                Write-CimProperty -StringBuilder $StringBuilder -CimProperty $property -Path ($Path + $property.Name) -ResourceName $ResourceName
            }
            else
            {
                $paths = foreach ($p in $Path) { "['$p']" }
                $null = $StringBuilder.AppendLine("$($property.Name) = `$Parameters$($paths -join '')['$($property.Name)']")
            }
        }
    }
    $null = $StringBuilder.AppendLine('}')
}

function Get-PropertiesData
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Path
    )

    $paths = foreach ($p in $Path) { "['$p']" }

    $pathValue = try
    {
        Invoke-Expression "`$Properties$($paths -join '')"
    }
    catch
    {
        $null
    }

    return $pathValue
}

function Get-CimType
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$DscResourceName,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    $cimType = $allDscResourcePropertiesTable."$ResourceName-$PropertyName"

    if ($null -eq $cimType)
    {
        Write-Verbose "The CIM Type for DSC resource '$DscResourceName' with the name '$PropertyName'. It is not a CIM type."
        return
    }

    return $cimType
}

function Get-DynamicTypeObject
{
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true)]
        [object]$Object
    )

    if ($Object.ElementType)
    {
        return $Object.Type.GetElementType()
    }
    elseif ($Object.PropertyType)
    {
        return $Object.PropertyType
    }
    elseif ($Object.Type)
    {
        return $Object.Type
    }
    else
    {
        return $Object
    }
}

function Get-DscSplattedResource3
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $ResourceName,

        [Parameter()]
        [String]
        $ExecutionName,

        [Parameter()]
        [hashtable]
        $Properties,

        [Parameter()]
        [switch]
        $NoInvoke
    )

    if (-not $script:allDscResourcePropertiesTable -and -not $script:allDscResourcePropertiesTableWarningShown) {
        Write-Warning -Message "The 'allDscResourcePropertiesTable' is not defined. This will be an expensive operation. Resources with MOF sub-types are only supported when calling 'Initialize-DscResourceMetaInfo' once before starting the compilation process."
        $script:allDscResourcePropertiesTableWarningShown = $true
    }

    $standardCimTypes = Get-StandardCimType

    # Remove Case Sensitivity of ordered Dictionary or Hashtables
    $Properties = @{} + $Properties

    $stringBuilder = [System.Text.StringBuilder]::new()
    $null = $stringBuilder.AppendLine("Param([hashtable]`$Parameters)")
    $null = $stringBuilder.AppendLine()

    if ($ExecutionName)
    {
        $null = $stringBuilder.AppendLine("$ResourceName '$ExecutionName' {")
    }
    else
    {
        $null = $stringBuilder.AppendLine("$ResourceName {")
    }

    foreach ($PropertyName in $Properties.Keys) {

        $cimType = $allDscResourcePropertiesTable."$ResourceName-$PropertyName"
        if ($cimType)
        {
            $cimTypeConstraint = $cimType.TypeConstraint.Replace('[]', '')
            $isCimArray = $cimType.TypeConstraint.EndsWith("[]")
            $cimClass = $allDscSchemaClasses | Where-Object CimClassName -eq $cimTypeConstraint
            $cimProperties = $Properties.$PropertyName
            $null = $stringBuilder.AppendLine("$PropertyName = {0}" -f $(if ($isCimArray) { '@(' } else { "$($cimType.TypeConstraint.Replace('[]', '')) {" }))
            if ($isCimArray)
            {
                if ($Properties.$PropertyName -isnot [array])
                {
                    Write-Warning -Message "The property '$PropertyName' is an array and the BindingInfo data is not an array" -ErrorAction Stop
                }

                $i = 0
                foreach ($cimPropertyValue in $cimProperties)
                {
                    $null = $stringBuilder.AppendLine($cimType.TypeConstraint.Replace('[]', ''))
                    $null = $stringBuilder.AppendLine("{")

                    foreach ($cimSubProperty in $cimPropertyValue.GetEnumerator())
                    {
                        if (
                            ($null -ne $cimType.Type -and $cimType.Type.GetElementType().GetProperty($cimSubProperty.Name).PropertyType.IsArray) -or
                            ($null -eq $cimType.Type -and $cimType.TypeConstraint -like '*[[]]')
                        )
                        {
                            $null = $stringBuilder.AppendLine("$($cimSubProperty.Name) = @(")
                            try {
                                if ($null -ne $cimType.Type)
                                {
                                    $arrayItemTypeName = $cimType.Type.GetElementType().GetProperty($cimSubProperty.Name).PropertyType.GetElementType().Name
                                    $isCimSubArray = $cimType.Type.GetElementType().GetProperty($cimSubProperty.Name).PropertyType.GetElementType().FullName -notin $standardCimTypes.DotNetType
                                }
                                else {
                                    $x = $cimClass.CimClassProperties.Where({ $_.Name -eq $cimSubProperty.Name} )
                                    if ($x.CimType -eq 'Instance')
                                    {
                                        $arrayItemTypeName = $x.Qualifiers.Where({ $_.Name -eq 'EmbeddedInstance' }).Value
                                    }
                                    else
                                    {
                                        $arrayItemTypeName = $x.CimType
                                    }
                                    $isCimSubArray = $arrayItemTypeName -notin $standardCimTypes.CimType
                                }
                            }
                            catch {
                                'x'
                            }

                            $j = 0

                            foreach ($arrayItem in $cimSubProperty.Value)
                            {
                                if ($isCimSubArray)
                                {
                                    $null = $stringBuilder.AppendLine("$arrayItemTypeName {")

                                    foreach ($arrayItemKey in $arrayItem.Keys)
                                    {
                                        $null = $stringBuilder.AppendLine("$arrayItemKey = `$Parameters['$PropertyName'][$($i)]['$($cimSubProperty.Name)'][$($j)]['$($arrayItemKey)']")
                                    }

                                    $null = $stringBuilder.AppendLine('}')
                                }
                                else
                                {
                                    $null = $stringBuilder.AppendLine("@(`$Parameters['$PropertyName'][$($i)]['$($cimSubProperty.Name)'])[$($j)]")
                                }
                                $j++
                            }
                            $null = $stringBuilder.AppendLine(')')
                        }
                        else
                        {
                            $null = $stringBuilder.AppendLine("$($cimSubProperty.Name) = `$Parameters['$PropertyName'][$($i)]['$($cimSubProperty.Name)']")
                        }
                    }

                    $null = $stringBuilder.AppendLine("}")
                    $i++
                }

                $null = $stringBuilder.AppendLine('{0}' -f $(if ($isCimArray) { ')' }))
            }
            else
            {
                foreach ($cimProperty in $cimProperties.GetEnumerator())
                {
                    $null = $stringBuilder.AppendLine("$($cimProperty.Name) = `$Parameters['$PropertyName']['$($($cimProperty.Name))']")
                }

                $null = $stringBuilder.AppendLine("}")
            }
        }
        else
        {
            $null = $stringBuilder.AppendLine("$PropertyName = `$Parameters['$PropertyName']")
        }
    }

    $null = $stringBuilder.AppendLine("}")
    Write-Debug -Message ('Generated Resource Block = {0}' -f $stringBuilder.ToString())

    if ($NoInvoke)
    {
        [scriptblock]::Create($stringBuilder.ToString())
    }
    else
    {
        if ($Properties)
        {
            [scriptblock]::Create($stringBuilder.ToString()).Invoke($Properties)
        } else
        {
            [scriptblock]::Create($stringBuilder.ToString()).Invoke()
        }
    }
}

Set-Alias -Name x -Value Get-DscSplattedResource -Scope Global
#EndRegion '.\Public\Get-DscSplattedResource.ps1' 146
#Region '.\Public\Get-ModuleFromFolder.ps1' -1

function Get-ModuleFromFolder
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSModuleInfo[]])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo[]]
        $ModuleFolder,

        [Parameter()]
        [AllowNull()]
        [Microsoft.PowerShell.Commands.ModuleSpecification[]]
        $ExcludedModules
    )

    Begin
    {
        $allModulesInFolder = @()
    }

    Process
    {
        foreach ($Folder in $ModuleFolder)
        {
            Write-Debug -Message "Replacing Module path with $Folder"
            $oldPSModulePath = $env:PSModulePath
            $env:PSModulePath = $Folder
            Write-Debug -Message 'Discovering modules from folder'
            $allModulesInFolder += Get-Module -Refresh -ListAvailable
            Write-Debug -Message 'Reverting PSModulePath'
            $env:PSModulePath = $oldPSModulePath
        }
    }

    End
    {

        $allModulesInFolder | Where-Object {
            $source = $_
            Write-Debug -Message "Checking if module '$source' is sxcluded."
            $isExcluded = foreach ($excludedModule in $ExcludedModules)
            {
                Write-Debug "`t Excluded module '$ExcludedModule'"
                if (($excludedModule.Name -and $excludedModule.Name -eq $source.Name) -and
                    (
                        (-not $excludedModule.Version -and
                        -not $excludedModule.Guid -and
                        -not $excludedModule.MaximumVersion -and
                        -not $excludedModule.RequiredVersion ) -or
                        ($excludedModule.Version -and $excludedModule.Version -eq $source.Version) -or
                        ($excludedModule.Guid -and $excludedModule.Guid -ne $source.Guid) -or
                        ($excludedModule.MaximumVersion -and $excludedModule.MaximumVersion -ge $source.Version) -or
                        ($excludedModule.RequiredVersion -and $excludedModule.RequiredVersion -eq $source.Version)
                    )
                )
                {
                    Write-Debug ('Skipping {0} {1} {2}' -f $source.Name, $source.Version, $source.Guid)
                    return $false
                }
            }
            if (-not $isExcluded)
            {
                return $true
            }
        }
    }

}
#EndRegion '.\Public\Get-ModuleFromFolder.ps1' 70
#Region '.\Public\Initialize-DscResourceMetaInfo.ps1' -1

function Initialize-DscResourceMetaInfo
{
    param (
        [Parameter(Mandatory)]
        [string]
        $ModulePath,

        [Parameter()]
        [switch]
        $ReturnAllProperties,

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [switch]
        $PassThru
    )

    if ($script:allDscResourcePropertiesTable.Count -ne 0 -and -not $Force)
    {
        if ($PassThru)
        {
            return $script:allDscResourcePropertiesTable
        }
        else
        {
            return
        }
    }

    $allModules = Get-ModuleFromFolder -ModuleFolder $ModulePath
    $allDscResources = Get-DscResourceFromModuleInFolder -ModuleFolder $ModulePath -Modules $allModules
    $modulesWithDscResources = $allDscResources | Select-Object -ExpandProperty ModuleName -Unique
    $modulesWithDscResources = $allModules | Where-Object Name -In $modulesWithDscResources

    $standardCimTypes = Get-StandardCimType

    $script:allDscResourcePropertiesTable = @{}
    $script:allDscSchemaClasses = @()

    $script:allDscResourceProperties = foreach ($dscResource in $allDscResources)
    {
        $moduleInfo = $modulesWithDscResources |
                Where-Object { $_.Name -EQ $dscResource.ModuleName -and $_.Version -eq $dscResource.Version }

        try
        {
            $m = [System.Tuple]::Create($dscResource.Module.Name, [System.Version]$dscResource.Version)
            $exceptionCollection = [System.Collections.ObjectModel.Collection[System.Exception]]::new()
            $f = [System.IO.Path]::ChangeExtension($dscResource.Path, 'schema.mof')

            $dscSchemaClasses = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportClasses($f, $m, $exceptionCollection)
            foreach ($dscSchemaClass in $dscSchemaClasses)
            {
                $dscSchemaClass | Add-Member -Name ModuleName -MemberType NoteProperty -Value $dscResource.ModuleName
                $dscSchemaClass | Add-Member -Name ModuleVersion -MemberType NoteProperty -Value $dscResource.Version
                $dscSchemaClass | Add-Member -Name ResourceName -MemberType NoteProperty -Value $dscResource.Name
            }
            $script:allDscSchemaClasses += $dscSchemaClasses
        }
        catch
        {
            'x'
        }

        $cimProperties = if ($ReturnAllProperties)
        {
            Get-DscResourceProperty -ModuleInfo $moduleInfo -ResourceName $dscResource.Name
        }
        else
        {
            Get-DscResourceProperty -ModuleInfo $moduleInfo -ResourceName $dscResource.Name |
            Where-Object TypeConstraint -NotIn $standardCimTypes.CimType
        }

        foreach ($cimProperty in $cimProperties)
        {
            [PSCustomObject]@{
                Name           = $cimProperty.Name
                TypeConstraint = $cimProperty.TypeConstraint
                IsKey          = $cimProperty.IsKey
                Mandatory      = $cimProperty.Mandatory
                Values         = $cimProperty.Values
                Range          = $cimProperty.Range
                ModuleName     = $dscResource.ModuleName
                ResourceName   = $dscResource.Name
            }
            $script:allDscResourcePropertiesTable."$($dscResource.Name)-$($cimProperty.Name)" = $cimProperty
        }

    }

    if ($PassThru)
    {
        $script:allDscResourcePropertiesTable
    }
}
#EndRegion '.\Public\Initialize-DscResourceMetaInfo.ps1' 79
#Region '.\Public\Publish-DscConfiguration.ps1' -1

function Publish-DscConfiguration {
    [cmdletbinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(
            Mandatory
        )]
        [string]
        $DscBuildOutputConfigurations,

        [string]
        $PullServerWebConfig = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer\web.config"
    )
    Process {
        Write-Verbose "Publishing Configuration MOFs from $DscBuildOutputConfigurations"


        Get-ChildItem -Path (join-path -Path $DscBuildOutputConfigurations -ChildPath '*.mof') |
            foreach-object {
                if ( !(Test-Path -Path $PullServerWebConfig) ) {
                    Write-Warning "The Pull Server configg $PullServerWebConfig cannot be found."
                    Write-Warning "`t Skipping Publishing Configuration MOFs"
                }
                elseif ($pscmdlet.shouldprocess($_.BaseName)) {
                    Write-Verbose -Message "Publishing $($_.name)"
                    Publish-MOFToPullServer -FullName $_.FullName -PullServerWebConfig $PullServerWebConfig
                }
            }
    }
}
#EndRegion '.\Public\Publish-DscConfiguration.ps1' 30
#Region '.\Public\Publish-DscResourceModule.ps1' -1


function Publish-DscResourceModule {
    [cmdletbinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(
            Mandatory
        )]
        [string]
        $DscBuildOutputModules,

        [io.FileInfo]
        $PullServerWebConfig = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer\web.config"
    )
    Begin
    {
        if ( !(Test-Path $PullServerWebConfig) ) {
            if ($PSBoundParameters['ErrorAction'] -eq 'SilentlyContinue') {
                Write-Warning -Message "Could not find the Web.config of the pull Server at $PullServerWebConfig"
            }
            else {
                Throw "Could not find the Web.config of the pull Server at $PullServerWebConfig"
            }
            return
        }
        else {
            $webConfigXml = [xml](Get-Content -Raw -Path $PullServerWebConfig)
            $configXElement = $webConfigXml.SelectNodes("//appSettings/add[@key = 'ConfigurationPath']")
            $OutputFolderPath =  $configXElement.Value
        }
    }

    Process {
        if ($OutputFolderPath) {
            Write-Verbose 'Moving Processed Resource Modules from '
            Write-Verbose "`t$DscBuildOutputModules to"
            Write-Verbose "`t$OutputFolderPath"

            if ($pscmdlet.shouldprocess("copy $DscBuildOutputModules to $OutputFolderPath")) {
                Get-ChildItem -Path $DscBuildOutputModules -Include @('*.zip','*.checksum') |
                    Copy-Item -Destination $OutputFolderPath -Force
            }
        }
    }

}
#EndRegion '.\Public\Publish-DscResourceModule.ps1' 46
#Region '.\Public\Push-DscConfiguration.ps1' -1

function Push-DscConfiguration {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact='High'
    )]
    [Alias()]
    [OutputType([void])]
    Param (
        # Param1 help description
        [Parameter(Mandatory,
                    Position=0
                   ,ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.PSSession]
        $Session,

        # Param2 help description
        [Parameter()]
        [Alias('MOF','Path')]
        [System.IO.FileInfo]
        $ConfigurationDocument,

        # Param3 help description
        [Parameter()]
        [psmoduleinfo[]]
        $WithModule,

        [Parameter(
            ,Position = 1
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [Alias('DscBuildOutputModules')]
        $StagingFolderPath = "$Env:TMP\DSC\BuildOutput\modules\",

        [Parameter(
            ,Position = 3
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        $RemoteStagingPath = '$Env:TMP\DSC\modules\',

        [Parameter(
            ,Position = 4
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [switch]
        $Force
    )


    process {
        if ($pscmdlet.ShouldProcess($Session.ComputerName, "Applying MOF $ConfigurationDocument")) {
            if ($WithModule) {
                Push-DscModuleToNode -Module $WithModule -StagingFolderPath $StagingFolderPath -RemoteStagingPath $RemoteStagingPath -Session $Session
            }

            Write-Verbose "Removing previously pushed configuration documents"
            $ResolvedRemoteStagingPath = Invoke-Command -Session $Session -ScriptBlock {
                $ResolvedStagingPath = $ExecutionContext.InvokeCommand.ExpandString($Using:RemoteStagingPath)
                $null = Get-item "$ResolvedStagingPath\*.mof" | Remove-Item -force -ErrorAction SilentlyContinue
                if (!(Test-Path $ResolvedStagingPath)) {
                    mkdir -Force $ResolvedStagingPath -ErrorAction Stop
                }
                Write-Output $ResolvedStagingPath
            } -ErrorAction Stop

            $RemoteConfigDocumentPath = [io.path]::Combine(
                $ResolvedRemoteStagingPath,
                'localhost.mof'
            )

            Copy-Item -ToSession $Session -Path $ConfigurationDocument -Destination $RemoteConfigDocumentPath -Force -ErrorAction Stop

            Write-Verbose "Attempting to apply $RemoteConfigDocumentPath on $($session.ComputerName)"
            Invoke-Command -Session $Session -scriptblock {
                Start-DscConfiguration -Wait -Force -Path $Using:ResolvedRemoteStagingPath -Verbose -ErrorAction Stop
            }
        }
    }
}
#EndRegion '.\Public\Push-DscConfiguration.ps1' 84
#Region '.\Public\Push-DscModuleToNode.ps1' -1

<#
    .SYNOPSIS
    Injects Modules via PS Session.

    .DESCRIPTION
    Injects the missing modules on a remote node via a PSSession.
    The module list is checked again the available modules from the remote computer,
    Any missing version is then zipped up and sent over the PS session,
    before being extracted in the root PSModulePath folder of the remote node.

    .PARAMETER Module
    A list of Modules required on the remote node. Those missing will be packaged based
    on their Path.

    .PARAMETER StagingFolderPath
    Staging folder where the modules are being zipped up locally before being sent accross.

    .PARAMETER Session
    Session to use to gather the missing modules and to copy the modules to.

    .PARAMETER RemoteStagingPath
    Path on the remote Node where the modules will be copied before extraction.

    .PARAMETER Force
    Force all modules to be re-zipped, re-sent, and re-extracted to the target node.

    .EXAMPLE
    Push-DscModuleToNode -Module (Get-ModuleFromFolder C:\src\SampleKitchen\modules) -Session $RemoteSession -StagingFolderPath "C:\BuildOutput"

#>
function Push-DscModuleToNode {
    [CmdletBinding()]
    [OutputType([void])]
    Param (
        # Param1 help description
        [Parameter(
             Mandatory
            ,Position = 0
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [Alias("ModuleInfo")]
        [System.Management.Automation.PSModuleInfo[]]
        $Module,

        [Parameter(
            ,Position = 1
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [Alias('DscBuildOutputModules')]
        $StagingFolderPath = "$Env:TMP\DSC\BuildOutput\modules\",


        [Parameter(
            ,Mandatory
            ,Position = 2
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [System.Management.Automation.Runspaces.PSSession]
        $Session,

        [Parameter(
            ,Position = 3
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        $RemoteStagingPath = '$Env:TMP\DSC\modules\',

        [Parameter(
            ,Position = 4
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [switch]
        $Force
    )

    process
    {
        # Find the modules already available remotely
        if (!$Force) {
            $RemoteModuleAvailable = Invoke-command -Session $Session -ScriptBlock {Get-Module -ListAvailable}
        }
        $ResolvedRemoteStagingPath = Invoke-command -Session $Session -ScriptBlock {
            $ResolvedStagingPath = $ExecutionContext.InvokeCommand.ExpandString($Using:RemoteStagingPath)
            if (!(Test-Path $ResolvedStagingPath)) {
                mkdir -Force $ResolvedStagingPath
            }
            $ResolvedStagingPath
        }

        # Find the modules missing on remote node
        $MissingModules = $Module.Where{
            $MatchingModule = foreach ($remoteModule in $RemoteModuleAvailable) {
                if(
                    $remoteModule.Name -eq $_.Name -and
                    $remoteModule.Version -eq $_.Version -and
                    $remoteModule.guid -eq $_.guid
                ) {
                    Write-Verbose "Module match: $($remoteModule.Name)"
                    $remoteModule
                }
            }
            if(!$MatchingModule) {
                Write-Verbose "Module not found: $($_.Name)"
                $_
            }
        }
        Write-Verbose "The Missing modules are $($MissingModules.Name -join ', ')"

        # Find the missing modules from the staging folder
        #  and publish it there
        Write-Verbose "looking for missing zip modules in $($StagingFolderPath)"
        $MissingModules.where{ !(Test-Path "$StagingFolderPath\$($_.Name)_$($_.version).zip")} |
            Compress-DscResourceModule -DscBuildOutputModules $StagingFolderPath

        # Copy missing modules to remote node if not present already
        foreach ($module in $MissingModules) {
            $FileName = "$($StagingFolderPath)/$($module.Name)_$($module.Version).zip"
            if ($Force -or !(invoke-command -Session $Session -ScriptBlock {
                    Param($FileName)
                    Test-Path $FileName
                } -ArgumentList $FileName))
            {
                Write-Verbose "Copying $fileName* to $ResolvedRemoteStagingPath"
                Invoke-Command -Session $Session -ScriptBlock {
                    param($PathToZips)
                    if (!(Test-Path $PathToZips)) {
                        mkdir $PathToZips -Force
                    }
                } -ArgumentList $ResolvedRemoteStagingPath

                Copy-Item -ToSession $Session `
                    -Path "$($StagingFolderPath)/$($module.Name)_$($module.Version)*" `
                    -Destination $ResolvedRemoteStagingPath `
                    -Force | Out-Null
            }
            else {
                Write-Verbose "The File is already present remotely."
            }
        }

        # Extract missing modules on remote node to PSModulePath
        Write-Verbose "Expanding $ResolvedRemoteStagingPath/*.zip to $Env:CommonProgramW6432\WindowsPowerShell\Modules\$($Module.Name)\$($module.version)"
        Invoke-Command -Session $Session -ScriptBlock {
            Param($MissingModules,$PathToZips)
            foreach ($module in $MissingModules) {
                $fileName = "$($module.Name)_$($module.version).zip"
                Write-Verbose "Expanding $PathToZips/$fileName to $Env:CommonProgramW6432\WindowsPowerShell\Modules\$($Module.Name)\$($module.version)"
                Expand-Archive -Path "$PathToZips/$fileName" -DestinationPath "$Env:ProgramW6432\WindowsPowerShell\Modules\$($Module.Name)\$($module.version)" -Force
            }
        } -ArgumentList $MissingModules,$ResolvedRemoteStagingPath
    }
}
#EndRegion '.\Public\Push-DscModuleToNode.ps1' 157
#Region '.\Public\Remove-DscResourceWmiClass.ps1' -1

<#
    .Synopsis
        Removes a WMI class from the DSC namespace.
    .Description
        Removes a WMI class from the DSC namespace.
    .Example
        Get-DscResourceWmiClass -Class tmp* | Remove-DscResourceWmiClass
    .Example
        Remove-DscResourceWmiClass -Class 'tmpD460'
#>
function Remove-DscResourceWmiClass {
    param (
        #The WMI Class name to remove.  Supports wildcards.
        [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [alias('Name')]
        [string]
        $ResourceType
    )
    begin {
        $DscNamespace = "root/Microsoft/Windows/DesiredStateConfiguration"
    }
    process {
        #Have to use WMI here because I can't find how to delete a WMI instance via the CIM cmdlets.
        (Get-wmiobject -Namespace $DscNamespace -list -Class $ResourceType).psbase.delete()
    }
}
#EndRegion '.\Public\Remove-DscResourceWmiClass.ps1' 27
#Region '.\Public\Test-DscResourceFromModuleInFolderIsValid.ps1' -1

function Test-DscResourceFromModuleInFolderIsValid {
    [cmdletbinding()]
    param (
        [Parameter(
            Mandatory
        )]
        [ValidateNotNullOrEmpty()]
        [System.io.DirectoryInfo]
        $ModuleFolder,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ValueFromPipeline
        )]
        [System.Management.Automation.PSModuleInfo[]]
        [AllowNull()]
        $Modules
    )

    Process {
        Foreach ($module in $Modules) {
            $Resources = Get-DscResourceFromModuleInFolder -ModuleFolder $ModuleFolder `
                                                          -Modules $module

            $Resources.Where{$_.ImplementedAs -eq 'PowerShell'} | Assert-DscModuleResourceIsValid
        }
    }
}
#EndRegion '.\Public\Test-DscResourceFromModuleInFolderIsValid.ps1' 30
