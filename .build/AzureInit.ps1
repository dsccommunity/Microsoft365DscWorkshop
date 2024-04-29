Task AzureInit {

    try {
        Remove-Module -Name Az.Accounts -ErrorAction SilentlyContinue
        Import-Module -Name Az.Resources -ErrorAction SilentlyContinue
    }
    catch {
        Write-Verbose 'There were issues importing the Az modules.'
    }

    $datum = New-DatumStructure -DefinitionFile $ProjectPath\source\Datum.yml
    $global:azBuildParameters = @{}

    foreach ($env in $datum.Global.Azure.Environments.GetEnumerator())
    {
        if (-not $env.Value.AzKeyVaultTenantId)
        {
            Write-Host "AzKeyVaultTenantId is not defined for environment $($env.Name). Using AzTenantId."
            $env.Value.AzKeyVaultTenantId = $env.Value.AzTenantId
        }

        if (-not $env.Value.AzTenantId)
        {
            Write-Error "AzTenantId is not defined for environment $($env.Name)" -ErrorAction Stop
        }

        $global:azBuildParameters."$($env.Name)" = @{
            AzTenantId   = $env.Value.AzTenantId
            AzTenantName = $env.Value.AzTenantName
        }

        if (-not $env.Value.AzKeyVaultServicePrincipalApplicationId)
        {
            Write-Build DarkGray "'AzKeyVaultServicePrincipalApplicationId' not defined."
        }
        else
        {
            $param = @{
                ApplicationId       = $env.Value.AzKeyVaultServicePrincipalApplicationId
                CertificatePath     = "$ProjectPath\assets\certificates\$($env.Value.AzKeyVaultServicePrincipalName).pfx"
                CertificatePassword = ($env.Value.AzKeyVaultServicePrincipalCertificatePassword | ConvertTo-SecureString -AsPlainText -Force)
                Tenant              = $env.Value.AzKeyVaultTenantId
            }

            Write-Build DarkGray "Connecting to Azure environment '$($env.Name)' with KeyVault reader service principal '$($env.Value.AzKeyVaultServicePrincipalName)'..." -NoNewline
            Connect-AzAccount @param

            $global:azBuildParameters."$($env.Name)".Add('AzKeyVaultNameServicePrincipalName', $env.Value.AzKeyVaultServicePrincipalName)
            $global:azBuildParameters."$($env.Name)".Add('AzKeyVaultNameServicePrincipalAppId', $env.Value.AzKeyVaultServicePrincipalApplicationId)
            $global:azBuildParameters."$($env.Name)".Add('AzWorkerServicePrincipalName', $env.Value.AzWorkerServicePrincipalName)
            $global:azBuildParameters."$($env.Name)".Add('AzworkerServicePrincipalAppId', $env.Value.AzWorkerServicePrincipalApplicationId)

            $secret = Get-AzKeyVaultSecret -VaultName $env.Value.AzKeyVaultName -Name $env.Value.AzWorkerServicePrincipalName
            if (-not $secret)
            {
                Write-Error "The secret '$($env.Value.AzWorkerServicePrincipalName)' was not found in the KeyVault '$($env.Value.AzKeyVaultName)'."
            }

            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secret.SecretValue)
            $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)

            $bytes = [system.convert]::FromBase64String($result)
            $pfx = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)

            $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'CurrentUser')
            $store.Open('MaxAllowed')
            $store.Add($pfx)

            $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'LocalMachine')
            $store.Open('MaxAllowed')
            $store.Add($pfx)

            $global:azBuildParameters."$($env.Name)".AzWorkerServicePrincipalCertificateThumbprint = $pfx.Thumbprint
        }

    }
}
