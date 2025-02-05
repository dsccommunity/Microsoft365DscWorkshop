task ExportTenantData {

    $configPath = "$ProjectPath\export\ExportConfiguration.yml"
    $exportConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Yaml

    $environments = if ($env:BuildEnvironment)
    {
        $datum.Global.Azure.Environments.GetEnumerator().Where({ $_.Name -eq $env:BuildEnvironment })
    }
    else
    {
        $datum.Global.Azure.Environments.GetEnumerator()
    }

    foreach ($env in $environments)
    {
        Write-Host "Exporting configuration for environment '$($env.Name)'" -ForegroundColor Yellow
        if (-not $env.Value.AzTenantId)
        {
            Write-Error "AzTenantId is not defined for environment $($env.Name)" -ErrorAction Stop
        }

        $exportApp = $env.Value.Identities | Where-Object Name -EQ M365DscExportApplication
        if ($null -eq $exportApp)
        {
            Write-Error "Export application 'M365DscExportApplication' is not defined for environment $($env.Name)" -ErrorAction Stop
        }

        $exportParams = @{
            Components    = $exportConfig.DscResources
            ApplicationId = $exportApp.ApplicationId
            TenantId      = $env.Value.AzTenantName
            Path          = "$OutputDirectory\Export\$($env.Value.AzTenantName)"
        }
        if ($null -ne $exportApp.CertificateThumbprint)
        {
            $exportParams.CertificateThumbprint = $exportApp.CertificateThumbprint
        }
        elseif ($null -ne $exportApp.ApplicationSecret)
        {
            $exportParams.ApplicationSecret = $exportApp.applicationSecret
        }
        else
        {
            Write-Error "Export application 'M365DscExportApplication' does not have a certificate thumbprint or application secret defined for environment $($env.Name)" -ErrorAction Stop
        }

        Write-Host '------------------ Export Parameters ------------------' -ForegroundColor Yellow
        $exportParams | Out-String | Write-Host -ForegroundColor DarkGray
        Write-Host '-------------------------------------------------------' -ForegroundColor Yellow

        Export-M365DSCConfiguration @exportParam

    }

}

task InvokingDscExportConfiguration {

    Remove-Module -Name PSDesiredStateConfiguration -Force -ErrorAction SilentlyContinue

    $directories = dir -Path "$OutputDirectory\export" -Directory
    foreach ($directory in $directories)
    {
        $directory | Set-Location

        Write-Host "Invoking DSC configuration in directory $($directory.FullName)" -ForegroundColor Yellow
        dir -Path $Path -Recurse -Filter *.ps1 | ForEach-Object { & $_.FullName }
    }

    Set-Location -Path $ProjectPath

}

task ConvertMofToYaml {

    $allModules = Get-ModuleFromFolder -ModuleFolder .\output\RequiredModules\
    $m365dscModule = $allModules | Where-Object { $_.Name -eq 'Microsoft365DSC' }
    $modulesWithDscResources = Get-DscResourceFromModuleInFolder -ModuleFolder .\output\RequiredModules\ -Modules $m365dscModule
    $resourceTypes = $modulesWithDscResources | Select-Object -ExpandProperty ResourceType

    $tenants = Get-ChildItem -Path "$OutputDirectory\export" -Directory

    foreach ($tenant in $tenants)
    {
        $tenantData = Convert-MofToYaml -Path "$OutputDirectory\export\$($tenant.Name)\*.mof"
        $copiedData = Copy-YamlData -Data $tenantData -AllData $tenantData -ResourceTypes $resourceTypes

        Write-Host 'Exporting tenant configuration to the output folder as YAML' -ForegroundColor Yellow
        $copiedData | ConvertTo-Yaml | Out-File "$OutputDirectory\export\$($tenant.Name)\Configuration.yml" -Force
    }

}
