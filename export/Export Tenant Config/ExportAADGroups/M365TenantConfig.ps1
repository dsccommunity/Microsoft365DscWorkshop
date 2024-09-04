# Generated with Microsoft365DSC version 1.23.315.1
# For additional information on how to use Microsoft365DSC, please visit https://aka.ms/M365DSC
param (
)

Configuration M365TenantConfig
{
    param (
    )

    $OrganizationName = $ConfigurationData.NonNodeData.OrganizationName

    Import-DscResource -ModuleName 'Microsoft365DSC' -ModuleVersion '1.23.315.1'

    Node localhost
    {
        AADGroup 901c3979-2627-4e6e-bd37-c557aa29321d
        {
            DisplayName          = "ExchangeManagement";
            Ensure               = "Present";
            GroupTypes           = @();
            Id                   = "82eae72f-3265-45dd-8496-40f1c3188194";
            MailEnabled          = $False;
            MailNickname         = "e804d377-3";
            Managedidentity      = $True;
            MemberOf             = @();
            Members              = @();
            Owners               = @();
            SecurityEnabled      = $True;
            TenantId             = $ConfigurationData.NonNodeData.TenantId;
        }
        AADGroup 69903ae8-b3bf-482e-9f93-8ee67c5bee1c
        {
            Description          = "This is the default group for everyone in the network";
            DisplayName          = "All Company";
            Ensure               = "Present";
            GroupTypes           = @("Unified");
            Id                   = "8697e177-cae4-4cfc-b3a6-2cd729dc6a9e";
            MailEnabled          = $True;
            MailNickname         = "allcompany";
            Managedidentity      = $True;
            MemberOf             = @();
            Members              = @("admin@MngEnvMCAP576786.onmicrosoft.com","r.andree_live.com#EXT#@MngEnvMCAP576786.onmicrosoft.com");
            Owners               = @("admin@MngEnvMCAP576786.onmicrosoft.com");
            SecurityEnabled      = $False;
            TenantId             = $ConfigurationData.NonNodeData.TenantId;
            Visibility           = "Public";
        }
        O365Group cc97a405-5252-40d0-b85e-b1fdb6c114ae
        {
            Description          = "Test Group 3";
            DisplayName          = "Test Group 3";
            Ensure               = "Present";
            MailNickName         = "TestGroup3";
            ManagedBy            = @();
            Managedidentity      = $True;
            TenantId             = $ConfigurationData.NonNodeData.TenantId;
        }
        O365Group c263476f-3e8c-4250-9b49-640aff46743e
        {
            Description          = "Test Group 2";
            DisplayName          = "Test Group 2";
            Ensure               = "Present";
            MailNickName         = "TestGroup2";
            ManagedBy            = @();
            Managedidentity      = $True;
            TenantId             = $ConfigurationData.NonNodeData.TenantId;
        }
        O365Group 2dffaa81-4c99-49ef-9704-2ead7c575a0f
        {
            Description          = "";
            DisplayName          = "ExchangeManagement";
            Ensure               = "Present";
            MailNickName         = "e804d377-3";
            ManagedBy            = @();
            Managedidentity      = $True;
            TenantId             = $ConfigurationData.NonNodeData.TenantId;
        }
        O365Group 95227c13-6891-4cab-abac-36811f3b7624
        {
            Description          = "This is the default group for everyone in the network";
            DisplayName          = "All Company";
            Ensure               = "Present";
            MailNickName         = "allcompany";
            ManagedBy            = @("admin@MngEnvMCAP576786.onmicrosoft.com");
            Managedidentity      = $True;
            Members              = @("admin@MngEnvMCAP576786.onmicrosoft.com","r.andree_live.com#EXT#@MngEnvMCAP576786.onmicrosoft.com");
            TenantId             = $ConfigurationData.NonNodeData.TenantId;
        }
        O365Group 68a9b912-df0a-465b-8b4e-852cd65bfc7d
        {
            Description          = "Test Group 1";
            DisplayName          = "Test Group 1";
            Ensure               = "Present";
            MailNickName         = "TestGroup1";
            ManagedBy            = @();
            Managedidentity      = $True;
            TenantId             = $ConfigurationData.NonNodeData.TenantId;
        }
    }
}

M365TenantConfig -ConfigurationData .\ConfigurationData.psd1
