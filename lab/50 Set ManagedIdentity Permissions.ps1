$here = $PSScriptRoot
$requiredModulesPath = (Resolve-Path -Path $here\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $here\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $here\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $param = @{
        TenantId               = $environment.AzTenantId
        SubscriptionId         = $environment.AzSubscriptionId
        ServicePrincipalId     = $environment.AzApplicationId
        ServicePrincipalSecret = $environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    Connect-Azure @param -ErrorAction Stop

    Write-Host "Checking permissions for environment '$environmentName' (TenantId $($environment.AzTenantId), SubscriptionId $($environment.AzSubscriptionId))"

    $requiredPermissions = Get-M365DSCCompiledPermissionList2
    $permissions = Get-ServicePrincipalAppPermissions -DisplayName $datum.Global.ProjectSettings.Name

    $permissionDifference = (Compare-Object -ReferenceObject $requiredPermissions -DifferenceObject $permissions).InputObject

    if ($permissionDifference) {
        Write-Warning "There are $($permissionDifference.Count) differences in permissions for managed identity '$($datum.Global.ProjectSettings.Name)'"
        Write-Host "$($permissionDifference | ConvertTo-Json -Depth 10)"
        Write-Host

        Write-Host "Updating permissions for managed identity '$($datum.Global.ProjectSettings.Name)'"
        Set-ServicePrincipalAppPermissions -DisplayName $datum.Global.ProjectSettings.Name -Permissions $requiredPermissions
    }
    else {
        Write-Host "Permissions for managed identity '$($datum.Global.ProjectSettings.Name)' are up to date" -ForegroundColor Green
    }

}
