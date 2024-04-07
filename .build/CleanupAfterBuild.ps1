task ModuleCleanupBeforeBuild {

    #This task is subject to change depending on changing dependencies of the required modules
    Write-Host 'Cleaning up the required modules directory before the build process starts'
    if (Test-Path -Path $RequiredModulesDirectory\Microsoft.Graph.Authentication\2.16.0)
    {
        Remove-Item -Path $RequiredModulesDirectory\Microsoft.Graph.Authentication\2.16.0 -Recurse -Force
    }

    $path = "$RequiredModulesDirectory\MSCloudLoginAssistant\*\MSCloudLoginAssistant.psm1"
    $content = Get-Content -Path $path
    $content = $content.Replace("`$domain.Id.split('.')[0]", "`$domain.Id")
    $content | Set-Content -Path $path
}
