Import-Module -Name $ProjectPath\Lab\M365DscHelpers.psm1

task StartDscConfiguration {

    $environment = $env:buildEnvironment
    if (-not $environment)
    {
        Write-Error 'The build environment is not set'
    }

    Wait-DscLocalConfigurationManager

    $mofOutputDirectory = Join-Path -Path $OutputDirectory -ChildPath $MofOutputFolder
    Start-DscConfiguration -Path "$mofOutputDirectory\$environment" -Wait -Verbose -Force -ErrorAction Stop

}

task StartExistingDscConfiguration {

    Wait-DscLocalConfigurationManager

    Start-DscConfiguration -UseExisting -Wait -Verbose -Force -ErrorAction Stop

}

task TestDscConfiguration {

    Wait-DscLocalConfigurationManager -DoNotWaitForProcessToFinish

    $dscState = Write-M365DscStatusEvent -PassThru

    if (-not $dscState.InDesiredState)
    {
        Write-Host "The following $($dscState.ResourcesNotInDesiredState.Count) resource(s) are not in the desired state:" -ForegroundColor Red
        $dscState.ResourcesNotInDesiredState | ConvertTo-Yaml | Write-Host -ForegroundColor Yellow

        Write-Error -Message "Test failed, $($dscState.ResourcesNotInDesiredState.Count) resource(s) are not in the desired state. Please see the output above for more details."
    }
    else
    {
        Write-Host 'All resources are in the desired state' -ForegroundColor Green
    }
}

task CleanModuleFolder {

    $programFileModulePath = 'C:\Program Files\WindowsPowerShell\Modules'
    $modulesToKeep = 'Microsoft.PowerShell.Operation.Validation', 'PackageManagement', 'Pester', 'PowerShellGet', 'PSReadline'

    Wait-DscLocalConfigurationManager

    dir -Path $programFileModulePath |
        Where-Object { $_.BaseName -notin $modulesToKeep } |
            Remove-Item -Recurse -Force

}

task InitializeModuleFolder {

    $environment = $env:buildEnvironment
    if (-not $environment)
    {
        Write-Error 'The build environment is not set'
    }

    Wait-DscLocalConfigurationManager

    $programFileModulePath = 'C:\Program Files\WindowsPowerShell\Modules'
    $modulesToKeep = 'Microsoft.PowerShell.Operation.Validation', 'PackageManagement', 'Pester', 'PowerShellGet', 'PSReadline'

    Write-Host "Cleaning PowerShell module folder '$programFileModulePath'"
    Get-ChildItem -Path $programFileModulePath | Where-Object { $_.BaseName -notin $modulesToKeep } | ForEach-Object {

        Write-Host "Removing module '$($_.BaseName)'"
        $_ | Remove-Item -Recurse -Force
    }

    Write-Host "Copying modules from '$requiredModulesPath' to '$programFileModulePath'"
    Get-ChildItem -Path $requiredModulesPath | ForEach-Object {
        Write-Host "Copying module '$($_.BaseName)'"
        $_ | Copy-Item -Destination $programFileModulePath -Recurse -Force
    }

}
