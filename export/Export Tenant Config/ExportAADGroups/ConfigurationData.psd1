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
            # Tenant's default verified domain name
            OrganizationName = "MngEnvMCAP576786.onmicrosoft.com"

            # Azure AD Application Id for Authentication
            ApplicationId = "7365c036-169b-4d0b-907a-513eca20f6aa"

            # The Id or Name of the tenant to authenticate against
            TenantId = "b246c1af-87ab-41d8-9812-83cd5ff534cb"

            # Thumbprint of the certificate to use for authentication
            CertificateThumbprint = "dec3141c225b5fd8fe0fee87547e4ce2c71c7fa5"

        }
    )
}
