$requiredModules = @{
    'Az.ManagedServiceIdentity'           = 'latest'
    'Microsoft.Graph.Applications'        = '2.15.0'
    'Microsoft.Graph.Authentication'      = '2.15.0'
    'Microsoft.Graph.Identity.Governance' = '2.15.0'
    'Az.Resources'                        = 'latest'
    'Microsoft365DSC'                     = 'latest'
    'powershell-yaml'                     = 'latest'
    'VSTeam'                              = 'latest'
}

foreach ($module in $requiredModules.GetEnumerator()) {
    $param = @{
        Name  = $module.Name
        Scope = 'AllUsers'
        Force = $true
    }
    if ($module.Value -ne 'latest') {
        $param.RequiredVersion = $module.Value
    }

    $moduleInfo = Get-Module -Name $module -ListAvailable
    if ($module.Value -ne 'latest') {
        $moduleInfo = $moduleInfo | Where-Object Version -EQ $module.Value
    }

    if (-not ($moduleInfo)) {
        Write-Host "Installing module '$($module.Name)' with version '$($module.Value)'"
        Install-Module @param
    }
    else {
        Write-Host "Module '$($module.Name)' with version '$($moduel.Value)' is already installed"
    }
}
