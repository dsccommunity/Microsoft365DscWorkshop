@{
    AllNodes = @(
        @{
            NodeName                    = "localhost"
            PSDscAllowPlainTextPassword = $true;
            PSDscAllowDomainUser        = $true;
            #region Parameters
            # Default Value Used to Ensure a Configuration Data File is Generated
            ServerNumber = "0"

        }
    )
    NonNodeData = @(
        @{
            # Azure AD Application Id for Authentication
            ApplicationId = "2e9a61a5-bb7b-4b68-b40f-fab75790fd48"

            # The Id or Name of the tenant to authenticate against
            TenantId = "MngEnvMCAP576786.onmicrosoft.com"

            # Thumbprint of the certificate to use for authentication
            CertificateThumbprint = "c3ce6923f413083e1777eecc64fbd08195e0fd68"

            # Tenant's default verified domain name
            OrganizationName = "MngEnvMCAP576786.onmicrosoft.com"

        }
    )
}
