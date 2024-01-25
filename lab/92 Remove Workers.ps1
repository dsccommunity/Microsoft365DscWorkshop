$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$azDoData = Get-Content $here\..\source\Global\AzureDevOps.yml | ConvertFrom-Yaml

foreach ($lab in $labs) {
    $lab -match '(?:M365DscWorkshopWorker)(?<Environment>\w+)(?:\d{1,4})' | Out-Null
    $environmentName = $Matches.Environment
    $environment = $azureData.Environments.$environmentName
    Write-Host "Testing connection to environment '$environmentName'" -ForegroundColor Magenta
    
    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    try {
        $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
        Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"
    }
    catch {
        Write-Host "Failed to connect to environment '$environmentName' with error '$($_.Exception.Message)'" -ForegroundColor Red
        continue
    }

    Write-Host "Removing lab '$lab' for environment '$environmentName'" -ForegroundColor Magenta

    $lab = Import-Lab -Name $lab -NoValidation -PassThru

    Remove-Lab -Confirm:$false

    Write-Host "Successfully removed lab '$($lab.Name)'."
}

Set-VSTeamAccount -Account "https://dev.azure.com/$($azDoData.OrganizationName)/" -PersonalAccessToken $azDoData.PersonalAccessToken
Write-Host "Connected to Azure DevOps organization '$($azDoData.OrganizationName)' with PAT."

try {
    Get-VSTeamProject -Name $azDoData.ProjectName | Out-Null
    Remove-VSTeamProject -Name $azDoData.ProjectName -Force -ErrorAction Stop
    Write-Host "Project '$($azDoData.ProjectName)' has been removed."
}
catch {
    Write-Host "Project '$($azDoData.ProjectName)' does not exists."
}

if ($pool = Get-VSTeamPool | Where-Object Name -EQ $azDoData.AgentPoolName) {
    Remove-VSTeamPool -Id $pool.Id
    Write-Host "Agent pool '$($azDoData.AgentPoolName)' has been removed."
}
else {
    Write-Host "Agent pool '$($azDoData.AgentPoolName)' does not exists."
}

Write-Host 'Finished cleanup.'