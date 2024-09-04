# Generated with Microsoft365DSC version 1.24.717.1
# For additional information on how to use Microsoft365DSC, please visit https://aka.ms/M365DSC
param (
)

Configuration M365TenantConfig
{
    param (
    )

    $OrganizationName = $ConfigurationData.NonNodeData.OrganizationName

    Import-DscResource -ModuleName 'Microsoft365DSC' -ModuleVersion '1.24.717.1'

    Node localhost
    {
        AADConditionalAccessPolicy "AADConditionalAccessPolicy-SEC001-Block-Legacy-Authentication-All-App"
        {
            ApplicationEnforcedRestrictionsIsEnabled = $False;
            ApplicationId                            = $ConfigurationData.NonNodeData.ApplicationId;
            AuthenticationContexts                   = @();
            BuiltInControls                          = @("mfa");
            CertificateThumbprint                    = $ConfigurationData.NonNodeData.CertificateThumbprint;
            ClientAppTypes                           = @("exchangeActiveSync","other");
            CloudAppSecurityIsEnabled                = $False;
            CloudAppSecurityType                     = "";
            CustomAuthenticationFactors              = @();
            DeviceFilterRule                         = "";
            DisplayName                              = "SEC001-Block-Legacy-Authentication-All-App";
            Ensure                                   = "Present";
            ExcludeApplications                      = @();
            ExcludeExternalTenantsMembers            = @();
            ExcludeExternalTenantsMembershipKind     = "";
            ExcludeGroups                            = @();
            ExcludeLocations                         = @();
            ExcludePlatforms                         = @();
            ExcludeRoles                             = @();
            ExcludeUsers                             = @();
            GrantControlOperator                     = "OR";
            Id                                       = "1d0a97d9-c60a-466b-961b-d3a1719cf7f3";
            IncludeApplications                      = @("All");
            IncludeExternalTenantsMembers            = @();
            IncludeExternalTenantsMembershipKind     = "";
            IncludeGroups                            = @();
            IncludeLocations                         = @();
            IncludePlatforms                         = @();
            IncludeRoles                             = @();
            IncludeUserActions                       = @();
            IncludeUsers                             = @("All");
            PersistentBrowserIsEnabled               = $False;
            PersistentBrowserMode                    = "";
            SignInFrequencyIsEnabled                 = $False;
            SignInFrequencyType                      = "";
            SignInRiskLevels                         = @();
            State                                    = "enabledForReportingButNotEnforced";
            TenantId                                 = $OrganizationName;
            TransferMethods                          = "";
            UserRiskLevels                           = @();
        }
    }
}

M365TenantConfig -ConfigurationData .\ConfigurationData.psd1
