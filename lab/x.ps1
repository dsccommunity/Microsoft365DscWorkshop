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

    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))

    $tokenBody = @{     
        Grant_Type    = "client_credentials" 
        Scope         = "https://outlook.office365.com/.default"
        Client_Id     = $environment.AzApplicationId 
        Client_Secret = $environment.AzApplicationSecret
    }  

    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$($environment.AzTenantId)/oauth2/v2.0/token" -Method POST -Body $tokenBody 
    
    Connect-ExchangeOnline -AccessToken $tokenResponse.access_token -Organization $environment.AzTenantName

    #Connect-ExchangeOnline -Organization $environment.AzTenantName -Credential $cred

    Write-Host "Checking permissions for environment '$environmentName' (TenantId $($environment.AzTenantId), SubscriptionId $($environment.AzSubscriptionId))"

    $managedIdentityName = "Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)"

    $requiredPermissions = Get-M365DSCCompiledPermissionList2
    $permissions = Get-ServicePrincipalAppPermissions -DisplayName $managedIdentityName

    $permissionDifference = (Compare-Object -ReferenceObject $requiredPermissions -DifferenceObject $permissions).InputObject

    if ($permissionDifference) {
        Write-Warning "There are $($permissionDifference.Count) differences in permissions for managed identity '$managedIdentityName'"
        Write-Host "$($permissionDifference | ConvertTo-Json -Depth 10)"
        Write-Host

        Write-Host "Updating permissions for managed identity '$managedIdentityName'"
        Set-ServicePrincipalAppPermissions -DisplayName $managedIdentityName -Permissions $requiredPermissions
    }
    else {
        Write-Host "Permissions for managed identity '$managedIdentityName' are up to date" -ForegroundColor Green
    }

}
