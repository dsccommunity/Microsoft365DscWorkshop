$requiredModules = 'Az.ManagedServiceIdentity', 'Microsoft.Graph.Applications', 'Microsoft.Graph.Authentication', 'Az.Resources', 'Microsoft365DSC', 'powershell-yaml', 'VSTeam'

foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Host "Installing module '$module'"
        Install-Module -Name $module -Force -Scope AllUsers
    }
    else {
        Write-Host "Module '$module' is already installed"
    }
}
