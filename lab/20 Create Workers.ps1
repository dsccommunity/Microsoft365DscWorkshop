$here = $PSScriptRoot
$requiredModulesPath = (Resolve-Path -Path $here\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*") {
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

Import-Module -Name $here\AzHelpers.psm1 -Force
$datum = New-DatumStructure -DefinitionFile $here\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys

if (-not (Test-LabAzureModuleAvailability)) {
    Install-LabAzureRequiredModule -Scope AllUsers
}

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
}

foreach ($environmentName in $environments) {
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    $notes = @{
        Environment = $environmentName
    }

    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
    Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

    Write-Host "Creating lab for environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name)'"
    New-LabDefinition -Name "$($datum.Global.ProjectSettings.Name)$($environmentName)" -DefaultVirtualizationEngine Azure -Notes $notes

    Add-LabAzureSubscription -SubscriptionId $subscription.Context.Subscription.Id -DefaultLocation 'UK South'

    Set-LabInstallationCredential -Username Install -Password Somepass1

    $PSDefaultParameterValues = @{
        'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
        'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    }

    Add-LabDiskDefinition -Name "Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)Data1" -DiskSizeInGb 1000 -Label Data

    Add-LabMachineDefinition -Name "Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)" -AzureRoleSize Standard_D8lds_v5 -DiskName "Lcm$($datum.Global.ProjectSettings.Name)$($environmentName)Data1"

    Install-Lab

    Write-Host "Finished creating lab for environment '$environmentName' in the subscription '$($subscription.Context.Subscription.Name)'"

}
