Task ConfigDataPreparation {

    try
    {
        Remove-Module -Name Az.Accounts -ErrorAction SilentlyContinue
        Import-Module -Name Az.Resources -ErrorAction SilentlyContinue
    }
    catch
    {
        Write-Build Yellow 'There were issues importing the Az modules.'
    }

    $global:azBuildParameters = @{}

    foreach ($env in $datum.Global.Azure.Environments.GetEnumerator())
    {
        if (-not $env.Value.AzTenantId)
        {
            Write-Error "AzTenantId is not defined for environment $($env.Name)" -ErrorAction Stop
        }

        Write-Build DarkGray "`tAdding Azure environment '$($env.Name)' to build parameters."
        $global:azBuildParameters."$($env.Name)" = @{
            AzTenantId   = $env.Value.AzTenantId
            AzTenantName = $env.Value.AzTenantName
            Identities   = $env.Value.Identities | Where-Object { $_.CertificateThumbprint }
        }

    }
}
