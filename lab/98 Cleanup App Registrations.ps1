[CmdletBinding()]
param (
    [Parameter()]
    [string[]]$EnvironmentName
)

$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*")
{
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys
if ($EnvironmentName)
{
    $environments = $environments | Where-Object { $EnvironmentName -contains $_ }
}

foreach ($envName in $environments)
{
    $environment = $datum.Global.Azure.Environments.$envName
    Write-Host "Working in environment '$envName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    Connect-M365Dsc -TenantId $environment.AzTenantId -TenantName $environment.AzTenantName -SubscriptionId $environment.AzSubscriptionId
    if (-not (Test-M365DscConnection -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId))
    {
        Write-Error "Failed to connect to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'" -ErrorAction Stop
    }

    $environment.Identities += @{
        Name = "Lcm$($datum.Global.ProjectSettings.Name)$envName"
    }
    foreach ($identity in $environment.Identities.GetEnumerator())
    {
        $azIdentity = Get-M365DscIdentity -Name $identity.Name

        if (-not $azIdentity)
        {
            Write-Host "The application '$($identity.Name)' for environment '$envName' does not exist."
            continue
        }

        Write-Host "Removing the permissions for the application '$($identity.Name)' for environment '$envName'."
        Remove-M365DscIdentityPermission -Identity $azIdentity -SkipGraphApiPermissions

        Write-Host "Removing the application '$($identity.Name)' for environment '$envName'."
        Remove-M365DscIdentity -Identity $azIdentity

        if ($null -ne $azIdentity.CertificateThumbprint)
        {
            $certPath = "Cert:\LocalMachine\My\$($azIdentity.CertificateThumbprint)"
            if (Test-Path -Path $certPath)
            {
                Remove-Item -Path "Cert:\LocalMachine\My\$($azIdentity.CertificateThumbprint)" -Force
            }
            else
            {
                Write-Host "The certificate with thumbprint '$($azIdentity.CertificateThumbprint)' does not exist or has already been removed."
            }
        }

    }

    Disconnect-M365Dsc
    Write-Host "Finished working in environment '$envName'."

}

Write-Host 'Finished working in all environments'
