task NewM365DscDeltaReport {

    $sourceTenant = if ($env:DeltaReportSourceTenant)
    {
        $env:DeltaReportSourceTenant
    }
    else
    {
        Write-Error "The environment variable 'DeltaReportSourceTenant' is not set. Please specify the source tenant for the delta report." -ErrorAction Stop
    }

    $inputDirectory = if ($env:DeltaReportInputDirectory)
    {
        $env:DeltaReportInputDirectory
    }
    else
    {
        Join-Path -Path $OutputDirectory -ChildPath 'Export'
    }

    $reportDirectory = if ($env:DeltaReportOutputDirectory)
    {
        $env:DeltaReportOutputDirectory
    }
    else
    {
        Join-Path -Path $OutputDirectory -ChildPath 'DeltaReport'
    }

    if (-not (Test-Path -Path $inputDirectory))
    {
        Write-Error "The input directory '$inputDirectory' does not exist. Please download the 'TenantConfig-*' artifacts first." -ErrorAction Stop
    }

    Write-Host "Looking for exported tenant configurations in '$inputDirectory'" -ForegroundColor Yellow

    #The export creates '<Tenant>\<DscResource>\M365TenantConfig.ps1', hence the tenant is the grandparent of each configuration file.
    $tenants = Get-ChildItem -Path $inputDirectory -Filter *.ps1 -File -Recurse |
        Where-Object { $null -ne $_.Directory.Parent } |
            Group-Object -Property { $_.Directory.Parent.FullName }

    if ($tenants.Count -eq 0)
    {
        Write-Error "Could not find any exported DSC configuration (*.ps1) in '$inputDirectory'." -ErrorAction Stop
    }

    Write-Host "Found $($tenants.Count) tenant(s) in the input directory." -ForegroundColor Yellow

    $stagingDirectory = Join-Path -Path $reportDirectory -ChildPath '_staging'
    if (Test-Path -Path $reportDirectory)
    {
        Remove-Item -Path $reportDirectory -Recurse -Force
    }
    New-Item -Path $stagingDirectory -ItemType Directory -Force | Out-Null

    $mergedConfigurations = @{}

    foreach ($tenant in $tenants)
    {
        $tenantName = Split-Path -Path $tenant.Name -Leaf
        Write-Host "Merging $($tenant.Count) configuration file(s) of tenant '$tenantName'" -ForegroundColor Yellow

        $tenantStagingDirectory = Join-Path -Path $stagingDirectory -ChildPath $tenantName
        New-Item -Path $tenantStagingDirectory -ItemType Directory -Force | Out-Null

        #Join-M365DSCConfiguration merges all configurations of one folder into the base file, so the nested export structure has to be flattened first.
        $baseConfigurationFile = 'M365TenantConfig.ps1'
        $isBaseConfiguration = $true
        foreach ($configurationFile in ($tenant.Group | Sort-Object -Property FullName))
        {
            $targetName = if ($isBaseConfiguration)
            {
                $baseConfigurationFile
            }
            else
            {
                "$($configurationFile.Directory.Name).ps1"
            }
            $isBaseConfiguration = $false

            Copy-Item -Path $configurationFile.FullName -Destination (Join-Path -Path $tenantStagingDirectory -ChildPath $targetName) -Force
        }

        #Join-M365DSCConfiguration returns the merged configuration as a string instead of writing it to disk.
        $mergedConfiguration = Join-M365DSCConfiguration -ConfigurationFile $baseConfigurationFile -ConfigurationPath $tenantStagingDirectory

        if ([System.String]::IsNullOrWhiteSpace($mergedConfiguration))
        {
            Write-Error "Join-M365DSCConfiguration returned an empty configuration for tenant '$tenantName'." -ErrorAction Stop
        }

        $tenantConfigurationPath = Join-Path -Path $reportDirectory -ChildPath "$tenantName.ps1"
        Set-Content -Path $tenantConfigurationPath -Value $mergedConfiguration -Encoding utf8 -Force
        $mergedConfigurations.Add($tenantName, $tenantConfigurationPath)

        Write-Host "    Merged configuration written to '$tenantConfigurationPath'." -ForegroundColor Green
    }

    Remove-Item -Path $stagingDirectory -Recurse -Force

    if (-not $mergedConfigurations.ContainsKey($sourceTenant))
    {
        Write-Error "The source tenant '$sourceTenant' was not found in '$inputDirectory'. Available tenants: $($mergedConfigurations.Keys -join ', ')." -ErrorAction Stop
    }

    $destinationTenants = $mergedConfigurations.Keys | Where-Object { $_ -ne $sourceTenant } | Sort-Object
    if (-not $destinationTenants)
    {
        Write-Error "There is no tenant to compare the source tenant '$sourceTenant' with." -ErrorAction Stop
    }

    foreach ($destinationTenant in $destinationTenants)
    {
        $reportPath = Join-Path -Path $reportDirectory -ChildPath "DeltaReport-$sourceTenant-vs-$destinationTenant.html"
        Write-Host "Creating delta report of '$sourceTenant' against '$destinationTenant'" -ForegroundColor Yellow

        $Parameters = @{
            Source      = $mergedConfigurations[$sourceTenant]
            Destination = $mergedConfigurations[$destinationTenant]
            OutputPath  = $reportPath
            Type        = 'HTML'
            DriftOnly   = $true
        }
        New-M365DSCDeltaReport @Parameters

        Write-Host "    Delta report written to '$reportPath'." -ForegroundColor Green
    }

}
