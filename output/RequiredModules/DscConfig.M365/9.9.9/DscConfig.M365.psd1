@{
    RootModule        = 'DscConfig.M365.psm1'
    ModuleVersion     = '9.9.9'
    GUID              = '3ed9a67d-9e7e-4c59-86b3-4f4bfd929c31'
    Author            = 'DSC Community'
    CompanyName       = 'DSC Community'
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'
    Description       = 'DSC composite resource for https://github.com/dsccommunity/DscWorkshop'
    PowerShellVersion = '5.1'
    FunctionsToExport = '*'
    CmdletsToExport   = '*'
    VariablesToExport = '*'
    AliasesToExport   = '*'

    PrivateData       = @{

        PSData = @{
            Prerelease   = ''
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource')
            LicenseUri   = 'https://github.com/dsccommunity/DscConfig.M365/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/dsccommunity/DscConfig.M365'
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'
            ReleaseNotes = '## [0.3.1] - 2024-05-24

### Changed

- Excluding folder ''source/DSCResources'' from git.
- Updated these modules to latest version:
  - ProtectedData
  - DscBuildHelpers
- Updated to latest Sampler build scripts.

### Added

- Added test data for:
  - cEXOTransportRule
  - cEXODistributionGroup
  - cAADAdministrativeUnit
  - cAADAuthenticationMethodPolicy
  - cAADAuthenticationMethodPolicyAuthenticator
  - cAADAuthenticationMethodPolicyEmail
  - cAADAuthenticationMethodPolicyFido2
  - cAADAuthenticationMethodPolicySms
  - cAADAuthenticationMethodPolicySoftware
  - cAADAuthenticationMethodPolicyTemporary
  - cAADAuthenticationMethodPolicyVoice
  - cAADAuthenticationMethodPolicyX509
  - cAADAuthenticationStrengthPolicy
  - cO365OrgSettings

'
        }
    }
}
