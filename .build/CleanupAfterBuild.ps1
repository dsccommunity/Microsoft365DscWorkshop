task ModuleCleanupBeforeBuild {

    Write-Host 'Fixing issue in MSCloudLoginAssistant (https://github.com/microsoft/MSCloudLoginAssistant/issues/172)'
    $path = "$RequiredModulesDirectory\MSCloudLoginAssistant\*\MSCloudLoginAssistant.psm1"
    $content = Get-Content -Path $path
    $content = $content.Replace("`$domain.Id.split('.')[0]", "`$domain.Id")
    $content | Set-Content -Path $path

}
