task ModuleCleanupBeforeBuild {

    #This task is subject to change depending on changing dependencies of the required modules
    Write-Host 'Cleaning up the required modules directory before the build process starts'
    dir $RequiredModulesDirectory\Microsoft.Graph.Authentication | Where-Object { $_.Name -ne '2.15.0' } | Remove-Item -Recurse -Force

    Write-Host 'Fixing issue in MSCloudLoginAssistant (https://github.com/microsoft/MSCloudLoginAssistant/issues/172)'
    $path = "$RequiredModulesDirectory\MSCloudLoginAssistant\*\MSCloudLoginAssistant.psm1"
    $content = Get-Content -Path $path
    $content = $content.Replace("`$domain.Id.split('.')[0]", "`$domain.Id")
    $content | Set-Content -Path $path
}
