$requiredModules = 'Az.ManagedServiceIdentity',
'Microsoft.Graph.Applications',
'Microsoft.Graph.Authentication',
'Az.Resources',
'Microsoft365DSC',
'powershell-yaml',
'VSTeam'

foreach ($module in $requiredModules) {
    if (Get-Module -Name $module -ListAvailable) {
        Write-Host "Uninstalling module '$module'"
        Uninstall-Module -Name $module -Force 
    }
    else {
        Write-Host "Module '$module' is not installed"
    }
}
