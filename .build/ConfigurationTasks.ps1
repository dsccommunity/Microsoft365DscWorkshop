function Wait-DscLocalConfigurationManager
{
    [CmdletBinding()]
    param(
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
            Write-Verbose "LCM process was not running."
        }
    }
}

task StartDscConfiguration {

    $environment = $env:buildEnvironment
    if (-not $environment)
    {
        Write-Error 'The build environment is not set'
    }
    
    Wait-DscLocalConfigurationManager

    $MofOutputDirectory = Join-Path -Path $OutputDirectory -ChildPath $MofOutputFolder
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

    Start-DscConfiguration -Path "$MofOutputDirectory\$environment" -Wait -Verbose -Force -ErrorAction Stop

}

task TestDscConfiguration {
    
    Wait-DscLocalConfigurationManager -DoNotWaitForProcessToFinish
    
    $result = Test-DscConfiguration -Detailed -ErrorAction Stop

    if ($result.ResourcesNotInDesiredState)
    {
        Write-Host "The following $($result.ResourcesNotInDesiredState.ResourceId.Count) resources are not in the desired state:"

        foreach ($resourceId in $result.ResourcesNotInDesiredState.ResourceId)
        {
            Write-Host "`t$resourceId"
        }

        Write-Error 'Resources are not in desired state as listed above'
    }
    else
    {
        Write-Host 'All resources are in the desired state' -ForegroundColor Green
    }
}
