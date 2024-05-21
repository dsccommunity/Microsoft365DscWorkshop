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
            Prerelease   = '2024update0001'
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource')
            LicenseUri   = 'https://github.com/dsccommunity/DscConfig.M365/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/dsccommunity/DscConfig.M365'
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'
            ReleaseNotes = '## [0.3.0-2024update0001] - 2024-02-24

### Changed

- Build requires PowerShell 7 now.
- Fixed build issues by adding pre-release of ''DscBuildHelpers''.

'
        }
    }
}
