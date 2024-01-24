$requiredModules = 'Az.ManagedServiceIdentity', 'Microsoft.Graph.Applications', 'Microsoft.Graph.Authentication', 'Az.Resources', 'Microsoft365DSC', 'powershell-yaml', 'Azure.DevOps.Function.Collection'

foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Host "Uninstalling module '$module'"
        Uninstall-Module -Name $module -Force -Scope AllUsers
    }
    else {
        Write-Host "Module '$module' is not installed"
    }
}
