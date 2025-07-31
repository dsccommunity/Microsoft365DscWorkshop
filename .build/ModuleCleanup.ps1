task ModuleCleanup {

    $path = "$requiredModulesPath\PackageManagement"
    if (Test-Path -Path $path)
    {
        Remove-Item -Path $path -ErrorAction Stop -Recurse -Force
        Write-Host "Module 'PackageManagement' has been removed from the required modules folder."
    }

    $path = "$requiredModulesPath\PowerShellGet"
    if (Test-Path -Path $path)
    {
        Remove-Item -Path $path -ErrorAction Stop -Recurse -Force
        Write-Host "Module 'PowerShellGet' has been removed from the required modules folder."
    }

}
